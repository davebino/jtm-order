<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { supabase } from '../lib/supabaseClient'

interface PurchaseOrder {
  id: string
  po_number: string
  branch_id: string
  tanggal: string
  status: string
  notes: string | null
  branches?: { nama: string }
  purchase_order_items?: any[]
}

interface Branch {
  id: string
  kode: string
  nama: string
}

interface Product {
  id: string
  kode_barang: string
  nama: string
  harga: number
}

const purchaseOrders = ref<PurchaseOrder[]>([])
const branches = ref<Branch[]>([])
const products = ref<Product[]>([])
const isLoading = ref(false)
const error = ref<string | null>(null)

// Modal
const showModal = ref(false)
const modalMode = ref<'add' | 'edit' | 'view'>('add')
const editingPO = ref<PurchaseOrder | null>(null)

// Form
const form = ref({
  po_number: '',
  branch_id: '',
  tanggal: new Date().toISOString().split('T')[0],
  notes: '',
  items: [] as { product_id: string; qty_ordered: number; harga_satuan: number }[]
})
const formError = ref('')
const isSaving = ref(false)

onMounted(async () => {
  await Promise.all([fetchPOs(), fetchBranches(), fetchProducts()])
})

async function fetchPOs() {
  isLoading.value = true
  try {
    const { data, error: fetchError } = await supabase
      .from('purchase_orders')
      .select(`*, branches (nama), purchase_order_items (*, products (kode_barang, nama))`)
      .order('created_at', { ascending: false })
    
    if (fetchError) throw fetchError
    purchaseOrders.value = data || []
  } catch (err: any) {
    error.value = err.message
  } finally {
    isLoading.value = false
  }
}

async function fetchBranches() {
  const { data } = await supabase.from('branches').select('*').eq('is_active', true).order('nama')
  branches.value = data || []
}

async function fetchProducts() {
  const { data } = await supabase.from('products').select('id, kode_barang, nama, harga').eq('is_active', true).order('nama')
  products.value = data || []
}

function generatePONumber() {
  const date = new Date()
  const prefix = `PO${date.getFullYear()}${String(date.getMonth() + 1).padStart(2, '0')}`
  const random = Math.floor(Math.random() * 1000).toString().padStart(3, '0')
  return `${prefix}-${random}`
}

function openAddModal() {
  modalMode.value = 'add'
  form.value = {
    po_number: generatePONumber(),
    branch_id: '',
    tanggal: new Date().toISOString().split('T')[0],
    notes: '',
    items: [{ product_id: '', qty_ordered: 1, harga_satuan: 0 }]
  }
  formError.value = ''
  showModal.value = true
}

function addItem() {
  form.value.items.push({ product_id: '', qty_ordered: 1, harga_satuan: 0 })
}

function removeItem(index: number) {
  form.value.items.splice(index, 1)
}

function updateItemPrice(index: number) {
  const product = products.value.find(p => p.id === form.value.items[index].product_id)
  if (product) {
    form.value.items[index].harga_satuan = product.harga
  }
}

function closeModal() {
  showModal.value = false
  editingPO.value = null
}

async function handleSubmit() {
  formError.value = ''
  
  if (!form.value.branch_id) {
    formError.value = 'Pilih cabang'
    return
  }
  
  if (form.value.items.length === 0 || form.value.items.some(i => !i.product_id)) {
    formError.value = 'Tambahkan minimal 1 item'
    return
  }

  isSaving.value = true
  try {
    // Insert PO
    const { data: poData, error: poError } = await supabase
      .from('purchase_orders')
      .insert([{
        po_number: form.value.po_number,
        branch_id: form.value.branch_id,
        tanggal: form.value.tanggal,
        notes: form.value.notes,
        status: 'draft'
      }])
      .select()
      .single()
    
    if (poError) throw poError

    // Insert items
    const itemsToInsert = form.value.items.map(item => ({
      po_id: poData.id,
      product_id: item.product_id,
      qty_ordered: item.qty_ordered,
      harga_satuan: item.harga_satuan
    }))

    const { error: itemsError } = await supabase
      .from('purchase_order_items')
      .insert(itemsToInsert)
    
    if (itemsError) throw itemsError

    await fetchPOs()
    closeModal()
  } catch (err: any) {
    formError.value = err.message
  } finally {
    isSaving.value = false
  }
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

function getStatusClass(s: string) {
  const c: Record<string, string> = { draft: 'badge-gray', pending: 'badge-yellow', approved: 'badge-blue', received: 'badge-green', cancelled: 'badge-red' }
  return c[s] || 'badge-gray'
}
</script>

<template>
  <div class="pembelian-view">
    <div class="view-header">
      <div>
        <h2>Purchase Order</h2>
        <p>Kelola pembelian dari cabang ke principal</p>
      </div>
      <button @click="openAddModal" class="btn-primary">
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
            <th>Cabang</th>
            <th>Tanggal</th>
            <th>Items</th>
            <th>Status</th>
            <th>Aksi</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="po in purchaseOrders" :key="po.id">
            <td class="font-medium">{{ po.po_number }}</td>
            <td>{{ po.branches?.nama }}</td>
            <td>{{ formatDate(po.tanggal) }}</td>
            <td>{{ po.purchase_order_items?.length || 0 }} item</td>
            <td><span class="badge" :class="getStatusClass(po.status)">{{ po.status }}</span></td>
            <td>
              <div class="action-buttons">
                <button v-if="po.status === 'draft'" @click="updateStatus(po, 'pending')" class="btn-sm btn-outline" title="Ajukan">Ajukan</button>
                <button v-if="po.status === 'pending'" @click="updateStatus(po, 'approved')" class="btn-sm btn-success" title="Approve">Approve</button>
              </div>
            </td>
          </tr>
          <tr v-if="purchaseOrders.length === 0">
            <td colspan="6" class="empty-state"><i class="pi pi-shopping-cart"></i><p>Belum ada PO</p></td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Modal -->
    <div v-if="showModal" class="modal-overlay" @click.self="closeModal">
      <div class="modal-content modal-lg">
        <div class="modal-header">
          <h3>Buat Purchase Order</h3>
          <button @click="closeModal" class="btn-close"><i class="pi pi-times"></i></button>
        </div>

        <form @submit.prevent="handleSubmit" class="modal-form">
          <div class="form-grid">
            <div class="form-group">
              <label>No. PO</label>
              <input v-model="form.po_number" type="text" class="form-input" disabled />
            </div>
            <div class="form-group">
              <label>Tanggal</label>
              <input v-model="form.tanggal" type="date" class="form-input" />
            </div>
            <div class="form-group col-span-2">
              <label>Cabang <span class="required">*</span></label>
              <select v-model="form.branch_id" class="form-input">
                <option value="">Pilih cabang...</option>
                <option v-for="b in branches" :key="b.id" :value="b.id">{{ b.nama }}</option>
              </select>
            </div>
            <div class="form-group col-span-2">
              <label>Catatan</label>
              <textarea v-model="form.notes" class="form-input" rows="2"></textarea>
            </div>
          </div>

          <div class="items-section">
            <div class="items-header">
              <h4>Items</h4>
              <button type="button" @click="addItem" class="btn-sm btn-outline">+ Tambah</button>
            </div>
            <table class="items-table">
              <thead>
                <tr><th>Barang</th><th>Qty</th><th>Harga</th><th></th></tr>
              </thead>
              <tbody>
                <tr v-for="(item, index) in form.items" :key="index">
                  <td>
                    <select v-model="item.product_id" @change="updateItemPrice(index)" class="form-input">
                      <option value="">Pilih...</option>
                      <option v-for="p in products" :key="p.id" :value="p.id">{{ p.kode_barang }} - {{ p.nama }}</option>
                    </select>
                  </td>
                  <td><input v-model.number="item.qty_ordered" type="number" min="1" class="form-input" style="width:80px" /></td>
                  <td>{{ formatCurrency(item.harga_satuan) }}</td>
                  <td><button type="button" @click="removeItem(index)" class="btn-icon btn-danger"><i class="pi pi-trash"></i></button></td>
                </tr>
              </tbody>
            </table>
          </div>

          <div v-if="formError" class="form-error"><i class="pi pi-exclamation-circle"></i> {{ formError }}</div>

          <div class="modal-actions">
            <button type="button" @click="closeModal" class="btn-secondary">Batal</button>
            <button type="submit" class="btn-primary" :disabled="isSaving">
              <i v-if="isSaving" class="pi pi-spin pi-spinner"></i> Simpan
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<style scoped>
.pembelian-view { max-width: 1400px; }
.view-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem; }
.view-header h2 { font-size: 1.5rem; font-weight: 700; color: #1f2937; margin-bottom: 0.25rem; }
.view-header p { color: #6b7280; font-size: 0.875rem; }

.btn-primary { display: inline-flex; align-items: center; gap: 0.5rem; padding: 0.75rem 1.25rem; background: linear-gradient(135deg, #FE0000, #cc0000); color: white; border: none; border-radius: 8px; font-weight: 600; font-size: 0.875rem; cursor: pointer; transition: all 0.2s; }
.btn-primary:hover:not(:disabled) { transform: translateY(-1px); box-shadow: 0 4px 12px rgba(254, 0, 0, 0.3); }
.btn-primary:disabled { opacity: 0.6; cursor: not-allowed; }
.btn-secondary { padding: 0.75rem 1.25rem; background: #f3f4f6; color: #374151; border: none; border-radius: 8px; font-weight: 600; cursor: pointer; }

.btn-sm { padding: 0.375rem 0.75rem; font-size: 0.75rem; border-radius: 4px; cursor: pointer; font-weight: 600; }
.btn-outline { background: transparent; border: 1px solid #254060; color: #254060; }
.btn-success { background: #16a34a; color: white; border: none; }

.error-alert { display: flex; align-items: center; gap: 0.5rem; padding: 1rem; background: #fef2f2; border: 1px solid #fecaca; border-radius: 8px; color: #dc2626; margin-bottom: 1rem; }
.loading-state { display: flex; align-items: center; justify-content: center; gap: 0.75rem; padding: 3rem; color: #6b7280; }

.table-card { background: white; border-radius: 12px; box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1); overflow: hidden; }
.data-table { width: 100%; border-collapse: collapse; }
.data-table th { padding: 0.875rem 1rem; text-align: left; font-size: 0.6875rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; color: #6b7280; background: #f9fafb; border-bottom: 1px solid #e5e7eb; }
.data-table td { padding: 0.875rem 1rem; font-size: 0.8125rem; border-bottom: 1px solid #e5e7eb; }
.font-medium { font-weight: 500; }

.badge { display: inline-block; padding: 0.25rem 0.5rem; border-radius: 4px; font-size: 0.6875rem; font-weight: 600; text-transform: uppercase; }
.badge-gray { background: #f3f4f6; color: #6b7280; }
.badge-yellow { background: #fef3c7; color: #92400e; }
.badge-blue { background: #dbeafe; color: #1e40af; }
.badge-green { background: #dcfce7; color: #166534; }
.badge-red { background: #fee2e2; color: #991b1b; }

.action-buttons { display: flex; gap: 0.5rem; }
.btn-icon { width: 28px; height: 28px; display: flex; align-items: center; justify-content: center; border: none; border-radius: 4px; background: #f3f4f6; color: #6b7280; cursor: pointer; }
.btn-icon.btn-danger { background: #fef2f2; color: #dc2626; }
.empty-state { text-align: center; padding: 2rem !important; color: #9ca3af; }
.empty-state i { font-size: 2rem; margin-bottom: 0.5rem; }

.modal-overlay { position: fixed; inset: 0; background: rgba(0, 0, 0, 0.5); display: flex; align-items: center; justify-content: center; z-index: 100; padding: 1rem; }
.modal-content { background: white; border-radius: 12px; width: 100%; max-width: 700px; max-height: 90vh; overflow-y: auto; }
.modal-lg { max-width: 700px; }
.modal-header { display: flex; justify-content: space-between; align-items: center; padding: 1.25rem 1.5rem; border-bottom: 1px solid #e5e7eb; position: sticky; top: 0; background: white; }
.modal-header h3 { font-size: 1.125rem; font-weight: 600; color: #1f2937; }
.btn-close { width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; border: none; border-radius: 6px; background: transparent; color: #6b7280; cursor: pointer; }
.modal-form { padding: 1.5rem; }
.form-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 1rem; margin-bottom: 1.5rem; }
.col-span-2 { grid-column: span 2; }
.form-group label { display: block; font-size: 0.8125rem; font-weight: 500; color: #374151; margin-bottom: 0.375rem; }
.required { color: #dc2626; }
.form-input { width: 100%; padding: 0.625rem 0.875rem; border: 1px solid #e5e7eb; border-radius: 6px; font-size: 0.875rem; }
.form-input:focus { outline: none; border-color: #254060; }
.form-input:disabled { background: #f9fafb; color: #6b7280; }

.items-section { margin-bottom: 1rem; }
.items-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.75rem; }
.items-header h4 { font-size: 0.9375rem; font-weight: 600; color: #1f2937; }
.items-table { width: 100%; border: 1px solid #e5e7eb; border-radius: 8px; }
.items-table th { padding: 0.5rem; background: #f9fafb; font-size: 0.75rem; text-align: left; }
.items-table td { padding: 0.5rem; }

.form-error { display: flex; align-items: center; gap: 0.5rem; padding: 0.75rem; background: #fef2f2; border-radius: 6px; color: #dc2626; font-size: 0.8125rem; margin-bottom: 1rem; }
.modal-actions { display: flex; justify-content: flex-end; gap: 0.75rem; padding-top: 1rem; border-top: 1px solid #e5e7eb; }
</style>
