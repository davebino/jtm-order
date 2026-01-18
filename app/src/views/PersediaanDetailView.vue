<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../lib/supabaseClient'
import { useAuthStore } from '../stores/authStore'
import { useActivityLog } from '../composables/useActivityLog'

interface Product {
  id: string
  kode_barang: string
  tipe: string | null
  kategori: string
  nama: string
  deskripsi: string | null
  harga: number
  satuan: string
  is_active: boolean
}

interface Branch {
  id: string
  kode: string
  nama: string
}

interface StockMovement {
  id: string
  branch_id: string
  movement_type: 'IN' | 'OUT' | 'ADJUSTMENT'
  qty: number
  qty_before: number
  qty_after: number
  reference_type: string | null
  notes: string | null
  created_at: string
  branch?: Branch
}

interface ProductStock {
  branch_id: string
  stock: number
  branch?: Branch
}

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const { logActivity } = useActivityLog()

const productId = computed(() => route.params.id as string)

const product = ref<Product | null>(null)
const branches = ref<Branch[]>([])
const stocks = ref<ProductStock[]>([])
const movements = ref<StockMovement[]>([])
const isLoading = ref(true)
const error = ref<string | null>(null)

// Selected branch for adding stock
const selectedBranch = ref<string>('')

// Modal
const showModal = ref(false)
const form = ref({
  branch_id: '',
  movement_type: 'IN' as 'IN' | 'OUT' | 'ADJUSTMENT',
  qty: 0,
  notes: ''
})
const formError = ref('')
const isSaving = ref(false)

// Computed
const currentStock = computed(() => {
  if (!form.value.branch_id) return 0
  const s = stocks.value.find(st => st.branch_id === form.value.branch_id)
  return s?.stock || 0
})

const totalStock = computed(() => {
  return stocks.value.reduce((sum, s) => sum + s.stock, 0)
})

onMounted(async () => {
  await fetchBranches()
  await loadProduct()
})

async function fetchBranches() {
  const { data } = await supabase.from('branches').select('*').eq('is_active', true).order('nama')
  branches.value = data || []
}

async function loadProduct() {
  isLoading.value = true
  error.value = null
  try {
    // Load product
    const { data: prod, error: prodError } = await supabase
      .from('products')
      .select('*')
      .eq('id', productId.value)
      .single()

    if (prodError) throw prodError
    product.value = prod

    // Load stocks per branch
    const { data: stockData } = await supabase
      .from('product_stocks')
      .select('*, branch:branches(*)')
      .eq('product_id', productId.value)

    stocks.value = stockData || []

    // Load movement history
    const { data: movementData } = await supabase
      .from('stock_movements')
      .select('*, branch:branches(*)')
      .eq('product_id', productId.value)
      .order('created_at', { ascending: false })
      .limit(50)

    movements.value = movementData || []
  } catch (err: any) {
    error.value = err.message
  } finally {
    isLoading.value = false
  }
}

function openModal() {
  form.value = { branch_id: '', movement_type: 'IN', qty: 0, notes: '' }
  formError.value = ''
  showModal.value = true
}

function closeModal() {
  showModal.value = false
}

async function handleSubmit() {
  formError.value = ''
  
  if (!form.value.branch_id || form.value.qty <= 0) {
    formError.value = 'Pilih cabang dan masukkan jumlah yang valid'
    return
  }

  if (form.value.movement_type === 'OUT' && form.value.qty > currentStock.value) {
    formError.value = `Stock tidak cukup. Stock saat ini: ${currentStock.value}`
    return
  }

  isSaving.value = true
  try {
    const stockBefore = currentStock.value
    let stockAfter = stockBefore

    if (form.value.movement_type === 'IN') {
      stockAfter = stockBefore + form.value.qty
    } else if (form.value.movement_type === 'OUT') {
      stockAfter = stockBefore - form.value.qty
    } else {
      stockAfter = form.value.qty
    }

    const { error: insertError } = await supabase
      .from('stock_movements')
      .insert([{
        product_id: productId.value,
        branch_id: form.value.branch_id,
        movement_type: form.value.movement_type,
        qty: form.value.movement_type === 'ADJUSTMENT' ? Math.abs(stockAfter - stockBefore) : form.value.qty,
        qty_before: stockBefore,
        qty_after: stockAfter,
        reference_type: 'MANUAL',
        notes: form.value.notes || null,
        created_by: authStore.user?.id
      }])
    
    if (insertError) throw insertError

    // Get branch name for logging
    const branchName = branches.value.find(b => b.id === form.value.branch_id)?.nama || ''
    const actionType = form.value.movement_type === 'IN' ? 'stock_in' : form.value.movement_type === 'OUT' ? 'stock_out' : 'stock_adjust'
    const actionDesc = form.value.movement_type === 'IN' 
      ? `Stock masuk: +${form.value.qty} di ${branchName}` 
      : form.value.movement_type === 'OUT' 
        ? `Stock keluar: -${form.value.qty} dari ${branchName}`
        : `Stock adjust: ${stockBefore} → ${stockAfter} di ${branchName}`

    // Log activity
    await logActivity({
      module: 'products',
      action: actionType,
      entity_id: productId.value,
      entity_name: product.value?.kode_barang || '',
      description: `${product.value?.nama}: ${actionDesc}`,
      new_value: { movement_type: form.value.movement_type, qty: form.value.qty, qty_before: stockBefore, qty_after: stockAfter },
      branch_id: form.value.branch_id
    })
    
    await loadProduct()
    closeModal()
  } catch (err: any) {
    formError.value = err.message
  } finally {
    isSaving.value = false
  }
}

function goBack() {
  router.push('/persediaan')
}

function formatDate(dateStr: string) {
  return new Date(dateStr).toLocaleString('id-ID', {
    day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit'
  })
}

function formatCurrency(value: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(value)
}

function getMovementBadgeClass(type: string) {
  switch (type) { case 'IN': return 'badge-in'; case 'OUT': return 'badge-out'; default: return 'badge-adj' }
}

function getMovementLabel(type: string) {
  switch (type) { case 'IN': return 'Masuk'; case 'OUT': return 'Keluar'; default: return 'Adjust' }
}
</script>

<template>
  <div class="detail-view">
    <!-- Header -->
    <div class="view-header">
      <div class="header-left">
        <button @click="goBack" class="btn-back">
          <i class="pi pi-arrow-left"></i>
        </button>
        <div>
          <h2>Detail Produk</h2>
          <p v-if="product">{{ product.kode_barang }}</p>
        </div>
      </div>
      <button @click="openModal" class="btn-primary">
        <i class="pi pi-plus"></i>
        Update Stock
      </button>
    </div>

    <!-- Loading -->
    <div v-if="isLoading" class="loading-state">
      <i class="pi pi-spin pi-spinner"></i>
      <span>Memuat data...</span>
    </div>

    <!-- Content -->
    <div v-else-if="product" class="content-grid">
      <!-- Product Info Card -->
      <div class="info-card">
        <div class="product-header">
          <span class="category-badge" :class="product.kategori === 'AMB' ? 'cat-amb' : 'cat-mcb'">
            {{ product.kategori === 'AMB' ? 'Aki Mobil' : 'Aki Motor' }}
          </span>
          <h3>{{ product.nama }}</h3>
          <p class="product-type">{{ product.tipe || '-' }}</p>
        </div>
        <div class="product-details">
          <div class="detail-row">
            <span class="label">Harga</span>
            <span class="value">{{ formatCurrency(product.harga) }}</span>
          </div>
          <div class="detail-row">
            <span class="label">Satuan</span>
            <span class="value">{{ product.satuan }}</span>
          </div>
          <div class="detail-row">
            <span class="label">Total Stock</span>
            <span class="value total-stock">{{ totalStock.toLocaleString() }}</span>
          </div>
        </div>
        <div v-if="product.deskripsi" class="product-desc">
          <span class="label">Deskripsi</span>
          <p>{{ product.deskripsi }}</p>
        </div>
      </div>

      <!-- Stock per Branch -->
      <div class="stock-card">
        <h4>Stock per Cabang</h4>
        <div class="stock-list">
          <div v-for="s in stocks" :key="s.branch_id" class="stock-item">
            <span class="branch-name">{{ s.branch?.nama || 'Unknown' }}</span>
            <span class="stock-qty" :class="s.stock < 10 ? 'low' : ''">{{ s.stock.toLocaleString() }}</span>
          </div>
          <div v-if="stocks.length === 0" class="empty-stock">
            <p>Belum ada data stock</p>
          </div>
        </div>
      </div>

      <!-- Movement History -->
      <div class="history-card">
        <h4>Riwayat Pergerakan Stock</h4>
        <div class="history-table-wrapper">
          <table class="history-table">
            <thead>
              <tr>
                <th>Waktu</th>
                <th>Cabang</th>
                <th>Tipe</th>
                <th>Qty</th>
                <th>Sebelum</th>
                <th>Sesudah</th>
                <th>Keterangan</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="m in movements" :key="m.id">
                <td class="text-muted">{{ formatDate(m.created_at) }}</td>
                <td>{{ m.branch?.nama || '-' }}</td>
                <td>
                  <span class="movement-badge" :class="getMovementBadgeClass(m.movement_type)">
                    {{ getMovementLabel(m.movement_type) }}
                  </span>
                </td>
                <td>
                  <span :class="m.movement_type === 'IN' ? 'text-green' : m.movement_type === 'OUT' ? 'text-red' : ''">
                    {{ m.movement_type === 'IN' ? '+' : m.movement_type === 'OUT' ? '-' : '' }}{{ m.qty }}
                  </span>
                </td>
                <td>{{ m.qty_before }}</td>
                <td class="font-medium">{{ m.qty_after }}</td>
                <td class="text-muted">{{ m.notes || '-' }}</td>
              </tr>
              <tr v-if="movements.length === 0">
                <td colspan="7" class="empty-state">
                  <p>Belum ada riwayat pergerakan</p>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="error-alert">
      <i class="pi pi-exclamation-circle"></i>
      {{ error }}
    </div>

    <!-- Add Stock Modal -->
    <div v-if="showModal" class="modal-overlay" @click.self="closeModal">
      <div class="modal-content">
        <div class="modal-header">
          <h3>Update Stock</h3>
          <button @click="closeModal" class="btn-close"><i class="pi pi-times"></i></button>
        </div>

        <form @submit.prevent="handleSubmit" class="modal-form">
          <div class="form-group">
            <label>Cabang <span class="required">*</span></label>
            <select v-model="form.branch_id" class="form-input">
              <option value="">Pilih Cabang</option>
              <option v-for="b in branches" :key="b.id" :value="b.id">{{ b.nama }}</option>
            </select>
            <div v-if="form.branch_id" class="current-stock">
              Stock saat ini di cabang ini: <strong>{{ currentStock }}</strong>
            </div>
          </div>

          <div class="form-group">
            <label>Tipe Transaksi <span class="required">*</span></label>
            <div class="type-buttons">
              <button type="button" @click="form.movement_type = 'IN'" :class="{ active: form.movement_type === 'IN' }" class="type-btn in">
                <i class="pi pi-arrow-down"></i> Masuk
              </button>
              <button type="button" @click="form.movement_type = 'OUT'" :class="{ active: form.movement_type === 'OUT' }" class="type-btn out">
                <i class="pi pi-arrow-up"></i> Keluar
              </button>
              <button type="button" @click="form.movement_type = 'ADJUSTMENT'" :class="{ active: form.movement_type === 'ADJUSTMENT' }" class="type-btn adj">
                <i class="pi pi-sliders-h"></i> Adjust
              </button>
            </div>
          </div>

          <div class="form-group">
            <label>{{ form.movement_type === 'ADJUSTMENT' ? 'Stock Baru' : 'Jumlah' }} <span class="required">*</span></label>
            <input v-model.number="form.qty" type="number" class="form-input" min="0" />
          </div>

          <div class="form-group">
            <label>Keterangan</label>
            <textarea v-model="form.notes" class="form-input" rows="2" placeholder="Opsional..."></textarea>
          </div>

          <div v-if="formError" class="form-error">
            <i class="pi pi-exclamation-circle"></i>
            {{ formError }}
          </div>

          <div class="modal-actions">
            <button type="button" @click="closeModal" class="btn-secondary">Batal</button>
            <button type="submit" class="btn-primary" :disabled="isSaving">
              <i v-if="isSaving" class="pi pi-spin pi-spinner"></i>
              Simpan
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<style scoped>
.detail-view { max-width: 1200px; }

.view-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem; flex-wrap: wrap; gap: 1rem; }
.header-left { display: flex; align-items: center; gap: 1rem; }
.view-header h2 { font-size: 1.5rem; font-weight: 700; color: #1f2937; margin-bottom: 0.25rem; }
.view-header p { color: #6b7280; font-size: 0.875rem; font-family: monospace; }

.btn-back { width: 40px; height: 40px; display: flex; align-items: center; justify-content: center; border: none; border-radius: 8px; background: #f3f4f6; color: #6b7280; cursor: pointer; }
.btn-back:hover { background: #e5e7eb; color: #374151; }

.btn-primary { display: inline-flex; align-items: center; gap: 0.5rem; padding: 0.75rem 1.25rem; background: linear-gradient(135deg, #FE0000, #cc0000); color: white; border: none; border-radius: 8px; font-weight: 600; font-size: 0.875rem; cursor: pointer; }
.btn-primary:hover:not(:disabled) { transform: translateY(-1px); box-shadow: 0 4px 12px rgba(254, 0, 0, 0.3); }
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }

.loading-state { display: flex; align-items: center; justify-content: center; gap: 0.75rem; padding: 3rem; color: #6b7280; }

.content-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem; }

@media (max-width: 768px) {
  .content-grid { grid-template-columns: 1fr; }
}

.info-card, .stock-card, .history-card { background: white; border-radius: 12px; padding: 1.5rem; box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1); }

.history-card { grid-column: span 2; }
@media (max-width: 768px) { .history-card { grid-column: span 1; } }

.product-header { margin-bottom: 1.5rem; }
.category-badge { display: inline-block; padding: 0.25rem 0.75rem; border-radius: 20px; font-size: 0.6875rem; font-weight: 700; margin-bottom: 0.5rem; }
.cat-amb { background: #dbeafe; color: #1e40af; }
.cat-mcb { background: #dcfce7; color: #166534; }

.product-header h3 { font-size: 1.25rem; font-weight: 700; color: #1f2937; margin-bottom: 0.25rem; }
.product-type { color: #6b7280; font-size: 0.875rem; }

.product-details { display: flex; flex-direction: column; gap: 0.75rem; }
.detail-row { display: flex; justify-content: space-between; align-items: center; padding: 0.5rem 0; border-bottom: 1px solid #f3f4f6; }
.detail-row .label { color: #6b7280; font-size: 0.8125rem; }
.detail-row .value { font-weight: 600; color: #1f2937; }
.total-stock { font-size: 1.25rem; color: #254060; }

.product-desc { margin-top: 1rem; padding-top: 1rem; border-top: 1px solid #e5e7eb; }
.product-desc .label { display: block; color: #6b7280; font-size: 0.8125rem; margin-bottom: 0.25rem; }
.product-desc p { color: #374151; font-size: 0.875rem; }

.stock-card h4, .history-card h4 { font-size: 1rem; font-weight: 600; color: #1f2937; margin-bottom: 1rem; }

.stock-list { display: flex; flex-direction: column; gap: 0.5rem; }
.stock-item { display: flex; justify-content: space-between; align-items: center; padding: 0.75rem; background: #f9fafb; border-radius: 8px; }
.branch-name { font-size: 0.875rem; font-weight: 500; color: #374151; }
.stock-qty { font-size: 1.125rem; font-weight: 700; color: #1f2937; }
.stock-qty.low { color: #dc2626; }
.empty-stock { text-align: center; padding: 1.5rem; color: #9ca3af; }

.history-table-wrapper { overflow-x: auto; }
.history-table { width: 100%; border-collapse: collapse; min-width: 600px; }
.history-table th { padding: 0.75rem; text-align: left; font-size: 0.6875rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; color: #6b7280; background: #f9fafb; border-bottom: 1px solid #e5e7eb; }
.history-table td { padding: 0.75rem; font-size: 0.8125rem; border-bottom: 1px solid #e5e7eb; }

.text-muted { color: #9ca3af; font-size: 0.75rem; }
.text-green { color: #16a34a; font-weight: 600; }
.text-red { color: #dc2626; font-weight: 600; }
.font-medium { font-weight: 500; }

.movement-badge { display: inline-block; padding: 0.25rem 0.5rem; border-radius: 4px; font-size: 0.6875rem; font-weight: 600; }
.badge-in { background: #dcfce7; color: #166534; }
.badge-out { background: #fef2f2; color: #dc2626; }
.badge-adj { background: #fef3c7; color: #92400e; }

.empty-state { text-align: center; padding: 2rem !important; color: #9ca3af; }

.error-alert { display: flex; align-items: center; gap: 0.5rem; padding: 1rem; border-radius: 8px; background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; }

/* Modal */
.modal-overlay { position: fixed; inset: 0; background: rgba(0, 0, 0, 0.5); display: flex; align-items: center; justify-content: center; z-index: 100; padding: 1rem; }
.modal-content { background: white; border-radius: 12px; width: 100%; max-width: 480px; }
.modal-header { display: flex; justify-content: space-between; align-items: center; padding: 1.25rem 1.5rem; border-bottom: 1px solid #e5e7eb; }
.modal-header h3 { font-size: 1.125rem; font-weight: 600; color: #1f2937; }
.btn-close { width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; border: none; border-radius: 6px; background: transparent; color: #6b7280; cursor: pointer; }
.modal-form { padding: 1.5rem; }

.form-group { margin-bottom: 1rem; }
.form-group label { display: block; font-size: 0.8125rem; font-weight: 500; color: #374151; margin-bottom: 0.375rem; }
.required { color: #dc2626; }
.form-input { width: 100%; padding: 0.625rem 0.875rem; border: 1px solid #e5e7eb; border-radius: 6px; font-size: 0.875rem; }
.form-input:focus { outline: none; border-color: #254060; }

.current-stock { margin-top: 0.5rem; font-size: 0.8125rem; color: #6b7280; }

.type-buttons { display: flex; gap: 0.5rem; }
.type-btn { flex: 1; display: flex; align-items: center; justify-content: center; gap: 0.375rem; padding: 0.75rem; border: 2px solid #e5e7eb; background: white; border-radius: 8px; font-size: 0.8125rem; font-weight: 500; color: #6b7280; cursor: pointer; transition: all 0.2s; }
.type-btn.in.active { border-color: #16a34a; background: #dcfce7; color: #16a34a; }
.type-btn.out.active { border-color: #dc2626; background: #fef2f2; color: #dc2626; }
.type-btn.adj.active { border-color: #f59e0b; background: #fef3c7; color: #92400e; }

.form-error { display: flex; align-items: center; gap: 0.5rem; padding: 0.75rem; background: #fef2f2; border-radius: 6px; color: #dc2626; font-size: 0.8125rem; margin-top: 1rem; }

.modal-actions { display: flex; justify-content: flex-end; gap: 0.75rem; padding-top: 1rem; border-top: 1px solid #e5e7eb; margin-top: 1rem; }
.btn-secondary { padding: 0.75rem 1.25rem; background: #f3f4f6; color: #374151; border: none; border-radius: 8px; font-weight: 600; cursor: pointer; }
</style>
