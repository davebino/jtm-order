<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabaseClient'

interface PurchaseOrder {
  id: string
  po_number: string
  branch_id: string
  supplier_id: string | null
  tanggal: string
  status: string
  notes: string | null
  branches?: { nama: string }
  suppliers?: { nama: string }
  purchase_order_items?: any[]
}

const router = useRouter()
const purchaseOrders = ref<PurchaseOrder[]>([])
const isLoading = ref(false)
const error = ref<string | null>(null)

onMounted(async () => {
  await fetchPOs()
})

async function fetchPOs() {
  isLoading.value = true
  try {
    const { data, error: fetchError } = await supabase
      .from('purchase_orders')
      .select(`*, branches (nama), suppliers (nama), purchase_order_items (*)`)
      .order('created_at', { ascending: false })
    
    if (fetchError) throw fetchError
    purchaseOrders.value = data || []
  } catch (err: any) {
    error.value = err.message
  } finally {
    isLoading.value = false
  }
}

function goToCreatePO() {
  router.push('/pembelian/create')
}

function goToEditPO(po: PurchaseOrder) {
  router.push(`/pembelian/${po.id}/edit`)
}

function goToViewPO(po: PurchaseOrder) {
  router.push(`/pembelian/${po.id}/edit`)
}

async function updateStatus(po: PurchaseOrder, newStatus: string) {
  await supabase.from('purchase_orders').update({ status: newStatus }).eq('id', po.id)
  await fetchPOs()
}

function formatDate(d: string) {
  return new Date(d).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' })
}

function formatCurrency(v: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(v)
}

function getTotal(po: PurchaseOrder) {
  if (!po.purchase_order_items) return 0
  return po.purchase_order_items.reduce((sum: number, item: any) => sum + (item.qty_ordered * item.harga_satuan), 0)
}

function getStatusClass(s: string) {
  const c: Record<string, string> = { 
    draft: 'badge-gray', 
    pending: 'badge-yellow', 
    approved: 'badge-blue', 
    received: 'badge-green', 
    cancelled: 'badge-red' 
  }
  return c[s] || 'badge-gray'
}

function getStatusLabel(s: string) {
  const l: Record<string, string> = {
    draft: 'Draft',
    pending: 'Menunggu',
    approved: 'Disetujui',
    received: 'Diterima',
    cancelled: 'Dibatalkan'
  }
  return l[s] || s
}
</script>

<template>
  <div class="pembelian-view">
    <div class="view-header">
      <div>
        <h2>Purchase Order</h2>
        <p>Kelola pembelian dari cabang ke principal</p>
      </div>
      <button @click="goToCreatePO" class="btn-primary">
        <i class="pi pi-plus"></i>
        Buat PO
      </button>
    </div>

    <div v-if="error" class="error-alert"><i class="pi pi-exclamation-circle"></i> {{ error }}</div>

    <div v-if="isLoading" class="loading-state"><i class="pi pi-spin pi-spinner"></i> Memuat data...</div>

    <div v-else class="table-card">
      <table class="data-table">
        <thead>
          <tr>
            <th>No. PO</th>
            <th>Pemasok</th>
            <th>Cabang</th>
            <th>Tanggal</th>
            <th>Items</th>
            <th>Total</th>
            <th>Status</th>
            <th>Aksi</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="po in purchaseOrders" :key="po.id">
            <td>
              <a @click="goToViewPO(po)" class="po-link">{{ po.po_number }}</a>
            </td>
            <td>{{ po.suppliers?.nama || '-' }}</td>
            <td>{{ po.branches?.nama || '-' }}</td>
            <td>{{ formatDate(po.tanggal) }}</td>
            <td>{{ po.purchase_order_items?.length || 0 }} item</td>
            <td class="font-medium">{{ formatCurrency(getTotal(po)) }}</td>
            <td><span class="badge" :class="getStatusClass(po.status)">{{ getStatusLabel(po.status) }}</span></td>
            <td>
              <div class="action-buttons">
                <button @click="goToEditPO(po)" class="btn-icon" title="Edit/Lihat">
                  <i class="pi pi-eye"></i>
                </button>
                <button v-if="po.status === 'draft'" @click="updateStatus(po, 'pending')" class="btn-sm btn-outline" title="Ajukan">Ajukan</button>
                <button v-if="po.status === 'pending'" @click="updateStatus(po, 'approved')" class="btn-sm btn-success" title="Approve">Approve</button>
              </div>
            </td>
          </tr>
          <tr v-if="purchaseOrders.length === 0">
            <td colspan="8" class="empty-state"><i class="pi pi-shopping-cart"></i><p>Belum ada PO. Klik "Buat PO" untuk memulai.</p></td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<style scoped>
.pembelian-view { max-width: 1400px; }
.view-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem; flex-wrap: wrap; gap: 1rem; }
.view-header h2 { font-size: 1.5rem; font-weight: 700; color: #1f2937; margin-bottom: 0.25rem; }
.view-header p { color: #6b7280; font-size: 0.875rem; }

.btn-primary { display: inline-flex; align-items: center; gap: 0.5rem; padding: 0.75rem 1.25rem; background: linear-gradient(135deg, #FE0000, #cc0000); color: white; border: none; border-radius: 8px; font-weight: 600; font-size: 0.875rem; cursor: pointer; transition: all 0.2s; }
.btn-primary:hover:not(:disabled) { transform: translateY(-1px); box-shadow: 0 4px 12px rgba(254, 0, 0, 0.3); }

.error-alert { display: flex; align-items: center; gap: 0.5rem; padding: 1rem; background: #fef2f2; border: 1px solid #fecaca; border-radius: 8px; color: #dc2626; margin-bottom: 1rem; }
.loading-state { display: flex; align-items: center; justify-content: center; gap: 0.75rem; padding: 3rem; color: #6b7280; }

.table-card { background: white; border-radius: 12px; box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1); overflow: hidden; }
.data-table { width: 100%; border-collapse: collapse; }
.data-table th { padding: 0.875rem 1rem; text-align: left; font-size: 0.6875rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; color: #6b7280; background: #f9fafb; border-bottom: 1px solid #e5e7eb; }
.data-table td { padding: 0.875rem 1rem; font-size: 0.8125rem; border-bottom: 1px solid #e5e7eb; }
.font-medium { font-weight: 500; }

.po-link { color: #254060; font-weight: 600; cursor: pointer; text-decoration: none; }
.po-link:hover { color: #FE0000; text-decoration: underline; }

.badge { display: inline-block; padding: 0.25rem 0.625rem; border-radius: 20px; font-size: 0.6875rem; font-weight: 600; }
.badge-gray { background: #f3f4f6; color: #6b7280; }
.badge-yellow { background: #fef3c7; color: #92400e; }
.badge-blue { background: #dbeafe; color: #1e40af; }
.badge-green { background: #dcfce7; color: #166534; }
.badge-red { background: #fee2e2; color: #991b1b; }

.action-buttons { display: flex; gap: 0.5rem; align-items: center; }
.btn-icon { width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; border: none; border-radius: 6px; background: #eff6ff; color: #1e40af; cursor: pointer; }
.btn-icon:hover { background: #dbeafe; }

.btn-sm { padding: 0.375rem 0.75rem; font-size: 0.75rem; border-radius: 4px; cursor: pointer; font-weight: 600; }
.btn-outline { background: transparent; border: 1px solid #254060; color: #254060; }
.btn-outline:hover { background: #254060; color: white; }
.btn-success { background: #16a34a; color: white; border: none; }
.btn-success:hover { background: #15803d; }

.empty-state { text-align: center; padding: 3rem !important; color: #9ca3af; }
.empty-state i { font-size: 2.5rem; margin-bottom: 0.75rem; display: block; }
.empty-state p { font-size: 0.875rem; }
</style>
