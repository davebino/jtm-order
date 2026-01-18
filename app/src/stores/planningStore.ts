/**
 * Planning Store (usePlanningStore)
 * 
 * Pinia store for managing sales planning data.
 * Handles:
 * - Fetching data from Supabase
 * - Transforming vertical DB data to horizontal pivoted format for grid
 * - Tracking local changes for batch updates
 * - Saving changes back to Supabase
 */

import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '../lib/supabaseClient'
import type {
    MasterProduct,
    MasterRegion,
    SalesPlanDetail,
    PivotedProductRow,
    MonthData,
    PlanningFilter
} from '../types/database.types'

export const usePlanningStore = defineStore('planning', () => {
    // ============================================
    // State
    // ============================================

    const products = ref<MasterProduct[]>([])
    const regions = ref<MasterRegion[]>([])
    const salesPlanDetails = ref<SalesPlanDetail[]>([])
    const pivotedData = ref<PivotedProductRow[]>([])

    // Loading states
    const isLoading = ref(false)
    const isSaving = ref(false)
    const error = ref<string | null>(null)

    // Current filter
    const currentFilter = ref<PlanningFilter>({
        region_id: null,
        kategori: null,
        year: new Date().getFullYear(),
        startMonth: 1,
        endMonth: 12
    })

    // Track modified cells for batch update
    const modifiedCells = ref<Map<string, MonthData>>(new Map())

    // ============================================
    // Getters
    // ============================================

    const hasUnsavedChanges = computed(() => modifiedCells.value.size > 0)

    const activeRegions = computed(() =>
        regions.value.filter((r: MasterRegion) => r.is_active)
    )

    const productsByCategory = computed(() => ({
        AMB: products.value.filter((p: MasterProduct) => p.kategori === 'AMB'),
        MCB: products.value.filter((p: MasterProduct) => p.kategori === 'MCB')
    }))

    // Generate month labels for the current filter range
    const monthColumns = computed(() => {
        const months: { key: string; label: string; date: string }[] = []
        const year = currentFilter.value.year

        for (let m = currentFilter.value.startMonth; m <= currentFilter.value.endMonth; m++) {
            const monthStr = m.toString().padStart(2, '0')
            const date = `${year}-${monthStr}-01`
            const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
                'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des']
            months.push({
                key: `${year}-${monthStr}`,
                label: `${monthNames[m - 1]} ${year}`,
                date
            })
        }
        return months
    })

    // ============================================
    // Actions
    // ============================================

    /**
     * Fetch master data (products and regions)
     */
    async function fetchMasterData() {
        isLoading.value = true
        error.value = null

        try {
            // Fetch products
            const { data: productData, error: productError } = await supabase
                .from('master_products')
                .select('*')
                .order('kategori')
                .order('kode_barang')

            if (productError) throw productError
            products.value = productData || []

            // Fetch regions
            const { data: regionData, error: regionError } = await supabase
                .from('master_regions')
                .select('*')
                .order('kode')

            if (regionError) throw regionError
            regions.value = regionData || []

        } catch (err: unknown) {
            error.value = err instanceof Error ? err.message : 'Failed to fetch master data'
            console.error('Error fetching master data:', err)
        } finally {
            isLoading.value = false
        }
    }

    /**
     * Fetch sales plan data based on current filter
     */
    async function fetchSalesPlans() {
        if (!currentFilter.value.region_id) {
            salesPlanDetails.value = []
            pivotedData.value = []
            return
        }

        isLoading.value = true
        error.value = null

        try {
            const year = currentFilter.value.year
            const startDate = `${year}-${currentFilter.value.startMonth.toString().padStart(2, '0')}-01`
            const endDate = `${year}-${currentFilter.value.endMonth.toString().padStart(2, '0')}-01`

            let query = supabase
                .from('v_sales_plans_detail')
                .select('*')
                .eq('region_id', currentFilter.value.region_id)
                .gte('bulan_tahun', startDate)
                .lte('bulan_tahun', endDate)
                .order('kategori')
                .order('kode_barang')
                .order('bulan_tahun')

            // Filter by category if specified
            if (currentFilter.value.kategori) {
                query = query.eq('kategori', currentFilter.value.kategori)
            }

            const { data, error: fetchError } = await query

            if (fetchError) throw fetchError
            salesPlanDetails.value = data || []

            // Transform to pivoted format
            transformToPivotedData()

        } catch (err: unknown) {
            error.value = err instanceof Error ? err.message : 'Failed to fetch sales plans'
            console.error('Error fetching sales plans:', err)
        } finally {
            isLoading.value = false
        }
    }

    /**
     * Transform vertical database records to horizontal pivoted format
     * This is the key transformation for Excel-like display
     */
    function transformToPivotedData() {
        const productMap = new Map<string, PivotedProductRow>()

        // Get filtered products
        let filteredProducts = products.value
        if (currentFilter.value.kategori) {
            filteredProducts = filteredProducts.filter((p: MasterProduct) => p.kategori === currentFilter.value.kategori)
        }

        // Initialize rows for all products (even those without sales data)
        for (const product of filteredProducts) {
            const row: PivotedProductRow = {
                product_id: product.id,
                kode_barang: product.kode_barang,
                nama_produk: product.nama_produk,
                tipe: product.tipe,
                kategori: product.kategori,
                std_pallet: product.std_pallet,
                isi_dus: product.isi_dus,
                region_id: currentFilter.value.region_id || '',
                region_kode: '',
                months: {}
            }

            // Initialize empty month data for each month in range
            for (const month of monthColumns.value) {
                row.months[month.key] = createEmptyMonthData(month.date, month.label)
            }

            productMap.set(product.id, row)
        }

        // Fill in actual data from sales plans
        for (const plan of salesPlanDetails.value) {
            const row = productMap.get(plan.product_id)
            if (!row) continue

            row.region_kode = plan.region_kode

            const monthKey = plan.bulan_tahun.substring(0, 7) // "YYYY-MM"
            if (row.months[monthKey]) {
                row.months[monthKey] = {
                    id: plan.id,
                    bulan_tahun: plan.bulan_tahun,
                    bulan_label: plan.bulan_label,
                    target_jual: plan.target_jual,
                    estimasi_jual: plan.estimasi_jual,
                    realisasi_sales: plan.realisasi_sales,
                    stok_awal: plan.stok_awal,
                    stok_akhir: plan.stok_akhir,
                    order_qty: plan.order_qty,
                    ito: plan.ito,
                    isModified: false
                }
            }
        }

        pivotedData.value = Array.from(productMap.values())
    }

    /**
     * Create empty month data for cells without existing records
     */
    function createEmptyMonthData(date: string, label: string): MonthData {
        return {
            id: null,
            bulan_tahun: date,
            bulan_label: label,
            target_jual: 0,
            estimasi_jual: 0,
            realisasi_sales: 0,
            stok_awal: 0,
            stok_akhir: 0,
            order_qty: 0,
            ito: 0,
            isModified: false
        }
    }

    /**
     * Update a cell value (tracked locally for batch save)
     */
    function updateCell(
        productId: string,
        monthKey: string,
        field: keyof MonthData,
        value: number
    ) {
        const row = pivotedData.value.find((r: PivotedProductRow) => r.product_id === productId)
        if (!row || !row.months[monthKey]) return

        const monthData = row.months[monthKey]

        // Update the value based on field
        switch (field) {
            case 'stok_awal':
                monthData.stok_awal = value
                break
            case 'order_qty':
                monthData.order_qty = value
                break
            case 'estimasi_jual':
                monthData.estimasi_jual = value
                break
            case 'target_jual':
                monthData.target_jual = value
                break
            case 'realisasi_sales':
                monthData.realisasi_sales = value
                break
            case 'ito':
                monthData.ito = value
                break
        }
        monthData.isModified = true

        // Auto-calculate stok_akhir when related fields change
        if (['stok_awal', 'order_qty', 'estimasi_jual'].includes(field)) {
            monthData.stok_akhir = monthData.stok_awal + monthData.order_qty - monthData.estimasi_jual
        }

        // Track modified cell
        const cellKey = `${productId}_${monthKey}`
        modifiedCells.value.set(cellKey, { ...monthData })
    }

    /**
     * Save all modified cells to Supabase (batch update)
     */
    async function saveChanges() {
        if (!hasUnsavedChanges.value) return

        isSaving.value = true
        error.value = null

        try {
            interface UpsertRecord {
                id?: string
                product_id: string
                region_id: string
                bulan_tahun: string
                target_jual: number
                estimasi_jual: number
                realisasi_sales: number
                stok_awal: number
                stok_akhir: number
                order_qty: number
                ito: number
            }
            const upsertData: UpsertRecord[] = []

            for (const [key, monthData] of modifiedCells.value) {
                const parts = key.split('_')
                const productId = parts[0]
                const regionId = currentFilter.value.region_id
                if (!regionId || !productId) continue

                const record: UpsertRecord = {
                    product_id: productId,
                    region_id: regionId,
                    bulan_tahun: monthData.bulan_tahun,
                    target_jual: monthData.target_jual,
                    estimasi_jual: monthData.estimasi_jual,
                    realisasi_sales: monthData.realisasi_sales,
                    stok_awal: monthData.stok_awal,
                    stok_akhir: monthData.stok_akhir,
                    order_qty: monthData.order_qty,
                    ito: monthData.ito
                }

                // Add id if exists (for update)
                if (monthData.id) {
                    record.id = monthData.id
                }

                upsertData.push(record)
            }

            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            const { error: upsertError } = await supabase
                .from('sales_plans')
                .upsert(upsertData as any, {
                    onConflict: 'product_id,region_id,bulan_tahun',
                    ignoreDuplicates: false
                })

            if (upsertError) throw upsertError

            // Clear modified cells and refresh data
            modifiedCells.value.clear()
            await fetchSalesPlans()

        } catch (err: unknown) {
            error.value = err instanceof Error ? err.message : 'Failed to save changes'
            console.error('Error saving changes:', err)
        } finally {
            isSaving.value = false
        }
    }

    /**
     * Discard all unsaved changes
     */
    function discardChanges() {
        modifiedCells.value.clear()
        transformToPivotedData() // Reset to original data
    }

    /**
     * Set filter and fetch data
     */
    async function setFilter(filter: Partial<PlanningFilter>) {
        currentFilter.value = { ...currentFilter.value, ...filter }
        if (currentFilter.value.region_id) {
            await fetchSalesPlans()
        }
    }

    /**
     * Initialize store - fetch all master data
     */
    async function initialize() {
        await fetchMasterData()
    }

    return {
        // State
        products,
        regions,
        salesPlanDetails,
        pivotedData,
        isLoading,
        isSaving,
        error,
        currentFilter,
        modifiedCells,

        // Getters
        hasUnsavedChanges,
        activeRegions,
        productsByCategory,
        monthColumns,

        // Actions
        fetchMasterData,
        fetchSalesPlans,
        updateCell,
        saveChanges,
        discardChanges,
        setFilter,
        initialize
    }
})
