/**
 * Database Type Definitions
 * 
 * TypeScript types matching the Supabase database schema.
 * These types are used for type-safe database operations.
 */

export type ProductCategory = 'AMB' | 'MCB'

export interface MasterProduct {
    id: string
    kode_barang: string
    nama_produk: string | null
    tipe: string
    kategori: ProductCategory
    std_pallet: number
    isi_dus: number
    created_at: string
    updated_at: string
}

export interface MasterRegion {
    id: string
    kode: string
    nama: string
    is_active: boolean
    created_at: string
}

export interface SalesPlan {
    id: string
    product_id: string
    region_id: string
    bulan_tahun: string  // DATE in ISO format (YYYY-MM-DD)
    target_jual: number
    estimasi_jual: number
    realisasi_sales: number
    stok_awal: number
    stok_akhir: number
    order_qty: number
    ito: number
    created_by: string | null
    created_at: string
    updated_at: string
}

// View type - denormalized sales plan with product and region details
export interface SalesPlanDetail {
    id: string
    bulan_tahun: string
    bulan_label: string
    tahun: number
    bulan: number
    product_id: string
    kode_barang: string
    nama_produk: string | null
    tipe: string
    kategori: ProductCategory
    std_pallet: number
    isi_dus: number
    region_id: string
    region_kode: string
    region_nama: string
    target_jual: number
    estimasi_jual: number
    realisasi_sales: number
    stok_awal: number
    stok_akhir: number
    order_qty: number
    ito: number
    achievement_pct: number
    created_at: string
    updated_at: string
}

// Database schema type for Supabase client
export interface Database {
    public: {
        Tables: {
            master_products: {
                Row: MasterProduct
                Insert: Omit<MasterProduct, 'id' | 'created_at' | 'updated_at'>
                Update: Partial<Omit<MasterProduct, 'id'>>
            }
            master_regions: {
                Row: MasterRegion
                Insert: Omit<MasterRegion, 'id' | 'created_at'>
                Update: Partial<Omit<MasterRegion, 'id'>>
            }
            sales_plans: {
                Row: SalesPlan
                Insert: Omit<SalesPlan, 'id' | 'created_at' | 'updated_at'>
                Update: Partial<Omit<SalesPlan, 'id'>>
            }
        }
        Views: {
            v_sales_plans_detail: {
                Row: SalesPlanDetail
            }
        }
        Enums: {
            product_category: ProductCategory
        }
    }
}

// ============================================
// Pivoted Data Types (for Grid Display)
// ============================================

/**
 * Represents a single month's data for a product
 */
export interface MonthData {
    id: string | null           // sales_plan id, null if no data yet
    bulan_tahun: string         // Date string YYYY-MM-01
    bulan_label: string         // "Jan 2026"
    target_jual: number
    estimasi_jual: number
    realisasi_sales: number
    stok_awal: number
    stok_akhir: number
    order_qty: number
    ito: number
    isModified?: boolean        // Track if cell was edited
}

/**
 * Pivoted row for grid display - one row per product
 * with dynamic month columns
 */
export interface PivotedProductRow {
    product_id: string
    kode_barang: string
    nama_produk: string | null
    tipe: string
    kategori: ProductCategory
    std_pallet: number
    isi_dus: number
    region_id: string
    region_kode: string
    // Dynamic month data - key is "YYYY-MM" format
    months: Record<string, MonthData>
}

/**
 * Filter options for the planning grid
 */
export interface PlanningFilter {
    region_id: string | null
    kategori: ProductCategory | null
    year: number
    startMonth: number  // 1-12
    endMonth: number    // 1-12
}
