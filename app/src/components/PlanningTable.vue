<script setup lang="ts">
/**
 * PlanningTable Component
 * 
 * Excel-like grid for sales planning using Ag-Grid Vue.
 * Features:
 * - Frozen left columns (Kode Barang, Tipe)
 * - Dynamic month columns
 * - Editable cells for Estimasi Jual and Order Qty
 * - Auto-calculated Stok Akhir
 * - Batch update support
 */

import { computed, ref } from 'vue'
import { AgGridVue } from 'ag-grid-vue3'
import { usePlanningStore } from '../stores/planningStore'
import { storeToRefs } from 'pinia'
import type { 
  ColDef, 
  ColGroupDef,
  CellValueChangedEvent,
  ICellRendererParams,
  ValueFormatterParams,
  ValueSetterParams,
  CellClassParams,
  CellStyleFunc
} from 'ag-grid-community'
import type { MonthData, PivotedProductRow } from '../types/database.types'

const store = usePlanningStore()
const { pivotedData, monthColumns, currentFilter, isLoading } = storeToRefs(store)

// Grid API reference
const gridApi = ref<unknown>(null)

// Default column definition
const defaultColDef: ColDef = {
  sortable: true,
  filter: true,
  resizable: true,
  minWidth: 80
}

// Number formatter
const numberFormatter = (params: ValueFormatterParams): string => {
  if (params.value === null || params.value === undefined) return ''
  return new Intl.NumberFormat('id-ID').format(params.value)
}

// Generate column definitions dynamically
const columnDefs = computed<(ColDef | ColGroupDef)[]>(() => {
  const cols: (ColDef | ColGroupDef)[] = [
    // Frozen columns (pinned left)
    {
      headerName: 'Kode Barang',
      field: 'kode_barang',
      pinned: 'left',
      width: 130,
      cellClass: 'font-mono font-medium'
    },
    {
      headerName: 'Tipe',
      field: 'tipe',
      pinned: 'left',
      width: 110,
      cellClass: 'font-semibold'
    },
    {
      headerName: 'Kategori',
      field: 'kategori',
      pinned: 'left',
      width: 80,
      cellRenderer: (params: ICellRendererParams): string => {
        const value = params.value
        if (value === 'AMB') {
          return '<span class="inline-badge-amb">AMB</span>'
        } else if (value === 'MCB') {
          return '<span class="inline-badge-mcb">MCB</span>'
        }
        return value
      }
    }
  ]
  
  // Dynamic month columns with grouping
  for (const month of monthColumns.value) {
    const monthGroup: ColGroupDef = {
      headerName: month.label,
      children: [
        {
          headerName: 'Stok Awal',
          field: `months_${month.key}_stok_awal`,
          width: 90,
          editable: true,
          valueFormatter: numberFormatter,
          cellClass: 'text-right',
          valueSetter: (params: ValueSetterParams): boolean => {
            const value = parseInt(params.newValue) || 0
            store.updateCell(params.data.product_id, month.key, 'stok_awal', value)
            return true
          }
        },
        {
          headerName: 'Order',
          field: `months_${month.key}_order_qty`,
          width: 90,
          editable: true,
          valueFormatter: numberFormatter,
          cellClass: 'text-right',
          cellStyle: { backgroundColor: '#eff6ff' },
          valueSetter: (params: ValueSetterParams): boolean => {
            const value = parseInt(params.newValue) || 0
            store.updateCell(params.data.product_id, month.key, 'order_qty', value)
            return true
          }
        },
        {
          headerName: 'Est. Jual',
          field: `months_${month.key}_estimasi_jual`,
          width: 90,
          editable: true,
          valueFormatter: numberFormatter,
          cellClass: 'text-right font-semibold',
          cellStyle: { backgroundColor: '#fefce8' },
          valueSetter: (params: ValueSetterParams): boolean => {
            const value = parseInt(params.newValue) || 0
            store.updateCell(params.data.product_id, month.key, 'estimasi_jual', value)
            return true
          }
        },
        {
          headerName: 'Stok Akhir',
          field: `months_${month.key}_stok_akhir`,
          width: 95,
          editable: false,
          valueFormatter: numberFormatter,
          cellClass: (params: CellClassParams): string => {
            const value = params.value || 0
            let classes = 'text-right font-medium '
            if (value < 0) {
              classes += 'text-red-600'
            } else if (value > 0) {
              classes += 'text-green-600'
            }
            return classes
          },
          cellStyle: ((params: CellClassParams) => {
            const value = params.value || 0
            if (value < 0) {
              return { backgroundColor: '#fef2f2', color: '#dc2626' }
            } else if (value > 0) {
              return { backgroundColor: '#f0fdf4', color: '#16a34a' }
            }
            return {}
          }) as CellStyleFunc
        },
        {
          headerName: 'ITO',
          field: `months_${month.key}_ito`,
          width: 70,
          editable: true,
          valueFormatter: (params: ValueFormatterParams): string => {
            if (params.value === null || params.value === undefined) return ''
            return Number(params.value).toFixed(2)
          },
          cellClass: 'text-right text-gray-500',
          valueSetter: (params: ValueSetterParams): boolean => {
            const value = parseFloat(params.newValue) || 0
            store.updateCell(params.data.product_id, month.key, 'ito', value)
            return true
          }
        }
      ]
    }
    cols.push(monthGroup)
  }
  
  return cols
})

// Row data getter - flatten nested object for Ag-Grid
const getRowData = (): Record<string, unknown>[] => {
  return pivotedData.value.map((row: PivotedProductRow) => {
    const flatRow: Record<string, unknown> = {
      product_id: row.product_id,
      kode_barang: row.kode_barang,
      tipe: row.tipe,
      kategori: row.kategori,
      nama_produk: row.nama_produk,
      std_pallet: row.std_pallet,
      isi_dus: row.isi_dus
    }
    
    // Flatten month data with underscore-separated keys
    for (const [monthKey, monthData] of Object.entries(row.months)) {
      const md = monthData as MonthData
      flatRow[`months_${monthKey}_stok_awal`] = md.stok_awal
      flatRow[`months_${monthKey}_order_qty`] = md.order_qty
      flatRow[`months_${monthKey}_estimasi_jual`] = md.estimasi_jual
      flatRow[`months_${monthKey}_stok_akhir`] = md.stok_akhir
      flatRow[`months_${monthKey}_ito`] = md.ito
    }
    
    return flatRow
  })
}

// Grid ready handler
const onGridReady = (params: { api: unknown }) => {
  gridApi.value = params.api
}

// Cell value changed handler
const onCellValueChanged = (event: CellValueChangedEvent) => {
  // Refresh the row to update calculated cells
  const api = gridApi.value as { refreshCells?: (params: { rowNodes: unknown[] }) => void } | null
  if (api?.refreshCells && event.node) {
    api.refreshCells({ rowNodes: [event.node] })
  }
}

// Export to CSV
const exportToCsv = () => {
  const api = gridApi.value as { exportDataAsCsv?: (params: { fileName: string }) => void } | null
  if (api?.exportDataAsCsv) {
    api.exportDataAsCsv({
      fileName: `planning_${currentFilter.value.region_id}_${currentFilter.value.year}.csv`
    })
  }
}
</script>

<template>
  <div class="planning-table-wrapper">
    <!-- Toolbar -->
    <div class="flex items-center justify-between p-4 bg-gray-50 border-b">
      <div class="flex items-center space-x-2">
        <span class="text-sm text-gray-600">
          <strong>{{ pivotedData.length }}</strong> produk
        </span>
        <span class="text-gray-300">|</span>
        <span class="text-sm text-gray-600">
          <strong>{{ monthColumns.length }}</strong> bulan
        </span>
      </div>
      <div class="flex items-center space-x-2">
        <button @click="exportToCsv" class="btn-outline text-sm py-1.5">
          <i class="pi pi-download mr-1"></i>
          Export CSV
        </button>
      </div>
    </div>
    
    <!-- Loading Overlay -->
    <div v-if="isLoading" class="flex items-center justify-center py-20">
      <div class="flex items-center space-x-3 text-gray-500">
        <i class="pi pi-spin pi-spinner text-2xl"></i>
        <span>Loading data...</span>
      </div>
    </div>
    
    <!-- Empty State -->
    <div v-else-if="pivotedData.length === 0" class="flex flex-col items-center justify-center py-20">
      <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mb-4">
        <i class="pi pi-table text-3xl text-gray-400"></i>
      </div>
      <h3 class="text-lg font-semibold text-gray-700">Tidak Ada Data</h3>
      <p class="text-gray-500 mt-1">Belum ada data planning untuk filter yang dipilih</p>
    </div>
    
    <!-- Ag-Grid -->
    <AgGridVue
      v-else
      class="ag-theme-alpine"
      style="height: 600px; width: 100%;"
      :columnDefs="columnDefs"
      :rowData="getRowData()"
      :defaultColDef="defaultColDef"
      :animateRows="true"
      :suppressRowClickSelection="true"
      rowSelection="multiple"
      @grid-ready="onGridReady"
      @cell-value-changed="onCellValueChanged"
    />
    
    <!-- Instructions -->
    <div class="p-4 bg-gray-50 border-t text-sm text-gray-500">
      <p>
        <i class="pi pi-info-circle mr-1"></i>
        <strong>Tips:</strong> Klik cell untuk edit. Tekan Enter untuk konfirmasi, Escape untuk batal.
        Kolom "Est. Jual" dan "Order" bisa diedit. "Stok Akhir" dihitung otomatis.
      </p>
    </div>
  </div>
</template>

<style scoped>
.planning-table-wrapper {
  background-color: white;
}

/* Override Ag-Grid styles */
:deep(.ag-header-cell-label) {
  justify-content: center;
}

:deep(.ag-header-group-cell-label) {
  justify-content: center;
  font-weight: 600;
}

:deep(.ag-cell) {
  display: flex;
  align-items: center;
}

:deep(.ag-cell.text-right) {
  justify-content: flex-end;
}

:deep(.ag-row-hover) {
  background-color: #f1f5f9 !important;
}

:deep(.inline-badge-amb),
:deep(.inline-badge-mcb) {
  font-size: 11px;
  padding: 2px 8px;
  border-radius: 4px;
  font-weight: 600;
}

:deep(.inline-badge-amb) {
  background-color: #dbeafe;
  color: #1e40af;
}

:deep(.inline-badge-mcb) {
  background-color: #dcfce7;
  color: #166534;
}
</style>
