<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { supabase } from '../lib/supabaseClient'
import { useAuthStore } from '../stores/authStore'

interface Product {
  id: string
  kode_barang: string
  tipe: string | null
  kategori: string
  nama: string
}

interface Branch {
  id: string
  kode: string
  nama: string
}

interface ProductStock {
  product_id: string
  branch_id: string
  stock: number
  product: Product
}

interface StockMovement {
  id: string
  product_id: string
  branch_id: string
  movement_type: 'IN' | 'OUT' | 'ADJUSTMENT'
  qty: number
  qty_before: number
  qty_after: number
  reference_type: string | null
  reference_number: string | null
  notes: string | null
  created_at: string
  product: Product
}

const authStore = useAuthStore()

const branches = ref<Branch[]>([])
const products = ref<Product[]>([])
const productStocks = ref<ProductStock[]>([])
const movements = ref<StockMovement[]>([])
const selectedBranch = ref<string>('')
const isLoading = ref(false)
const error = ref<string | null>(null)

// Modal
const showModal = ref(false)
const form = ref({
  product_id: '',
  movement_type: 'IN' as 'IN' | 'OUT' | 'ADJUSTMENT',
  qty: 0,
  notes: ''
})
const formError = ref('')
const isSaving = ref(false)

// View toggle
const viewMode = ref<'stock' | 'history'>('stock')

// Search
const searchQuery = ref('')

// Computed
const filteredStocks = computed(() => {
  if (!searchQuery.value) return productStocks.value
  const q = searchQuery.value.toLowerCase()
  return productStocks.value.filter(ps => 
    ps.product.kode_barang.toLowerCase().includes(q) ||
    ps.product.nama.toLowerCase().includes(q)
  )
})

const filteredMovements = computed(() => {
  if (!searchQuery.value) return movements.value
  const q = searchQuery.value.toLowerCase()
  return movements.value.filter(m => 
    m.product.kode_barang.toLowerCase().includes(q) ||
    m.product.nama.toLowerCase().includes(q)
  )
})

const selectedProductStock = computed(() => {
  if (!form.value.product_id || !selectedBranch.value) return 0
  const ps = productStocks.value.find(
    s => s.product_id === form.value.product_id && s.branch_id === selectedBranch.value
  )
  return ps?.stock || 0
})

onMounted(async () => {
  await fetchBranches()
  await fetchProducts()
})

watch(selectedBranch, () => {
  if (selectedBranch.value) {
    fetchStocks()
    fetchMovements()
  }
})

async function fetchBranches() {
  const { data } = await supabase.from('branches').select('*').eq('is_active', true).order('nama')
  branches.value = data || []
  if (branches.value.length > 0 && !selectedBranch.value) {
    selectedBranch.value = branches.value[0].id
  }
}

async function fetchProducts() {
  const { data } = await supabase.from('products').select('*').eq('is_active', true).order('nama')
  products.value = data || []
}

async function fetchStocks() {
  isLoading.value = true
  error.value = null
  try {
    const { data, error: fetchError } = await supabase
      .from('product_stocks')
      .select('*, product:products(*)')
      .eq('branch_id', selectedBranch.value)
      .order('stock', { ascending: false })
    
    if (fetchError) throw fetchError
    productStocks.value = data || []
  } catch (err: any) {
    error.value = err.message
  } finally {
    isLoading.value = false
  }
}

async function fetchMovements() {
  try {
    const { data, error: fetchError } = await supabase
      .from('stock_movements')
      .select('*, product:products(*)')
      .eq('branch_id', selectedBranch.value)
      .order('created_at', { ascending: false })
      .limit(100)
    
    if (fetchError) throw fetchError
    movements.value = data || []
  } catch (err: any) {
    console.error('Error fetching movements:', err)
  }
}

function openModal() {
  if (!selectedBranch.value) {
    error.value = 'Pilih cabang terlebih dahulu'
    return
  }
  form.value = { product_id: '', movement_type: 'IN', qty: 0, notes: '' }
  formError.value = ''
  showModal.value = true
}

function closeModal() {
  showModal.value = false
}

async function handleSubmit() {
  formError.value = ''
  
  if (!form.value.product_id || form.value.qty <= 0) {
    formError.value = 'Pilih produk dan masukkan jumlah yang valid'
    return
  }

  // Check if OUT and qty > current stock
  if (form.value.movement_type === 'OUT' && form.value.qty > selectedProductStock.value) {
    formError.value = `Stock tidak cukup. Stock saat ini: ${selectedProductStock.value}`
    return
  }

  isSaving.value = true
  try {
    const currentStock = selectedProductStock.value
    let newStock = currentStock

    if (form.value.movement_type === 'IN') {
      newStock = currentStock + form.value.qty
    } else if (form.value.movement_type === 'OUT') {
      newStock = currentStock - form.value.qty
    } else {
      newStock = form.value.qty // ADJUSTMENT sets absolute value
    }

    const { error: insertError } = await supabase
      .from('stock_movements')
      .insert([{
        product_id: form.value.product_id,
        branch_id: selectedBranch.value,
        movement_type: form.value.movement_type,
        qty: form.value.movement_type === 'ADJUSTMENT' ? Math.abs(newStock - currentStock) : form.value.qty,
        qty_before: currentStock,
        qty_after: newStock,
        reference_type: 'MANUAL',
        notes: form.value.notes || null,
        created_by: authStore.user?.id
      }])
    
    if (insertError) throw insertError
    
    await fetchStocks()
    await fetchMovements()
    closeModal()
  } catch (err: any) {
    formError.value = err.message
  } finally {
    isSaving.value = false
  }
}

function formatDate(dateStr: string) {
  return new Date(dateStr).toLocaleString('id-ID', {
    day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit'
  })
}

function getMovementBadgeClass(type: string) {
  switch (type) {
    case 'IN': return 'badge-in'
    case 'OUT': return 'badge-out'
    default: return 'badge-adj'
  }
}

function getMovementLabel(type: string) {
  switch (type) {
    case 'IN': return 'Masuk'
    case 'OUT': return 'Keluar'
    default: return 'Penyesuaian'
  }
}
</script>

<template>
  <div class="stock-view">
    <!-- Header -->
    <div class="view-header">
      <div>
        <h2>Pergerakan Stock</h2>
        <p>Kelola dan lihat riwayat pergerakan stock per cabang</p>
      </div>
      <div class="header-actions">
        <select v-model="selectedBranch" class="branch-select">
          <option value="" disabled>Pilih Cabang</option>
          <option v-for="b in branches" :key="b.id" :value="b.id">{{ b.nama }}</option>
        </select>
        <button @click="openModal" class="btn-primary" :disabled="!selectedBranch">
          <i class="pi pi-plus"></i>
          Tambah Transaksi
        </button>
      </div>
    </div>

    <!-- View Toggle -->
    <div class="view-toggle">
      <button @click="viewMode = 'stock'" :class="{ active: viewMode === 'stock' }">
        <i class="pi pi-box"></i> Stock Saat Ini
      </button>
      <button @click="viewMode = 'history'" :class="{ active: viewMode === 'history' }">
        <i class="pi pi-history"></i> Riwayat
      </button>
    </div>

    <!-- Search -->
    <div class="search-bar">
      <i class="pi pi-search"></i>
      <input v-model="searchQuery" type="text" placeholder="Cari produk..." />
    </div>

    <!-- Error -->
    <div v-if="error" class="error-alert">
      <i class="pi pi-exclamation-circle"></i>
      {{ error }}
    </div>

    <!-- No Branch -->
    <div v-if="!selectedBranch" class="info-alert">
      <i class="pi pi-info-circle"></i>
      Pilih cabang untuk melihat data stock
    </div>

    <!-- Loading -->
    <div v-else-if="isLoading" class="loading-state">
      <i class="pi pi-spin pi-spinner"></i>
      <span>Memuat data...</span>
    </div>

    <!-- Stock View -->
    <div v-else-if="viewMode === 'stock'" class="table-card">
      <table class="data-table">
        <thead>
          <tr>
            <th>Kode</th>
            <th>Nama Produk</th>
            <th>Kategori</th>
            <th>Stock</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="ps in filteredStocks" :key="ps.product_id">
            <td class="font-medium">{{ ps.product.kode_barang }}</td>
            <td>{{ ps.product.nama }}</td>
            <td>
              <span class="category-badge" :class="ps.product.kategori === 'AMB' ? 'cat-amb' : 'cat-mcb'">
                {{ ps.product.kategori }}
              </span>
            </td>
            <td>
              <span class="stock-value" :class="ps.stock < 10 ? 'low' : ''">
                {{ ps.stock.toLocaleString() }}
              </span>
            </td>
          </tr>
          <tr v-if="filteredStocks.length === 0">
            <td colspan="4" class="empty-state">
              <i class="pi pi-box"></i>
              <p>Belum ada data stock untuk cabang ini</p>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- History View -->
    <div v-else class="table-card">
      <table class="data-table">
        <thead>
          <tr>
            <th>Waktu</th>
            <th>Produk</th>
            <th>Tipe</th>
            <th>Qty</th>
            <th>Sebelum</th>
            <th>Sesudah</th>
            <th>Keterangan</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="m in filteredMovements" :key="m.id">
            <td class="text-muted">{{ formatDate(m.created_at) }}</td>
            <td class="font-medium">{{ m.product.nama }}</td>
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
          <tr v-if="filteredMovements.length === 0">
            <td colspan="7" class="empty-state">
              <i class="pi pi-history"></i>
              <p>Belum ada riwayat pergerakan stock</p>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Add Movement Modal -->
    <div v-if="showModal" class="modal-overlay" @click.self="closeModal">
      <div class="modal-content">
        <div class="modal-header">
          <h3>Tambah Transaksi Stock</h3>
          <button @click="closeModal" class="btn-close"><i class="pi pi-times"></i></button>
        </div>

        <form @submit.prevent="handleSubmit" class="modal-form">
          <div class="form-group">
            <label>Produk <span class="required">*</span></label>
            <select v-model="form.product_id" class="form-input">
              <option value="">Pilih Produk</option>
              <option v-for="p in products" :key="p.id" :value="p.id">
                {{ p.kode_barang }} - {{ p.nama }}
              </option>
            </select>
            <div v-if="form.product_id" class="current-stock">
              Stock saat ini: <strong>{{ selectedProductStock }}</strong>
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
.stock-view { max-width: 1400px; }

.view-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; flex-wrap: wrap; gap: 1rem; }
.view-header h2 { font-size: 1.5rem; font-weight: 700; color: #1f2937; margin-bottom: 0.25rem; }
.view-header p { color: #6b7280; font-size: 0.875rem; }

.header-actions { display: flex; gap: 0.75rem; align-items: center; }
.branch-select { padding: 0.625rem 1rem; border: 2px solid #254060; border-radius: 8px; font-size: 0.875rem; font-weight: 500; min-width: 180px; background: white; }

.btn-primary { display: inline-flex; align-items: center; gap: 0.5rem; padding: 0.75rem 1.25rem; background: linear-gradient(135deg, #FE0000, #cc0000); color: white; border: none; border-radius: 8px; font-weight: 600; font-size: 0.875rem; cursor: pointer; }
.btn-primary:hover:not(:disabled) { transform: translateY(-1px); box-shadow: 0 4px 12px rgba(254, 0, 0, 0.3); }
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }

.view-toggle { display: flex; gap: 0.5rem; margin-bottom: 1rem; }
.view-toggle button { display: flex; align-items: center; gap: 0.5rem; padding: 0.625rem 1rem; border: 1px solid #e5e7eb; background: white; border-radius: 8px; font-size: 0.875rem; font-weight: 500; color: #6b7280; cursor: pointer; }
.view-toggle button.active { background: #254060; color: white; border-color: #254060; }
.view-toggle button:hover:not(.active) { background: #f3f4f6; }

.search-bar { display: flex; align-items: center; gap: 0.75rem; padding: 0.625rem 1rem; background: white; border-radius: 8px; border: 1px solid #e5e7eb; margin-bottom: 1rem; max-width: 400px; }
.search-bar i { color: #9ca3af; }
.search-bar input { flex: 1; border: none; font-size: 0.875rem; outline: none; }

.error-alert, .info-alert { display: flex; align-items: center; gap: 0.5rem; padding: 1rem; border-radius: 8px; margin-bottom: 1rem; }
.error-alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; }
.info-alert { background: #eff6ff; border: 1px solid #bfdbfe; color: #1e40af; }

.loading-state { display: flex; align-items: center; justify-content: center; gap: 0.75rem; padding: 3rem; color: #6b7280; }

.table-card { background: white; border-radius: 12px; box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1); overflow: hidden; }
.data-table { width: 100%; border-collapse: collapse; }
.data-table th { padding: 0.875rem 1rem; text-align: left; font-size: 0.6875rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; color: #6b7280; background: #f9fafb; border-bottom: 1px solid #e5e7eb; }
.data-table td { padding: 0.875rem 1rem; font-size: 0.8125rem; border-bottom: 1px solid #e5e7eb; }

.font-medium { font-weight: 500; }
.text-muted { color: #9ca3af; font-size: 0.75rem; }
.text-green { color: #16a34a; font-weight: 600; }
.text-red { color: #dc2626; font-weight: 600; }

.category-badge { display: inline-block; padding: 0.25rem 0.625rem; border-radius: 4px; font-size: 0.6875rem; font-weight: 700; }
.cat-amb { background: #dbeafe; color: #1e40af; }
.cat-mcb { background: #dcfce7; color: #166534; }

.stock-value { font-weight: 600; font-size: 1rem; }
.stock-value.low { color: #dc2626; }

.movement-badge { display: inline-block; padding: 0.25rem 0.5rem; border-radius: 4px; font-size: 0.6875rem; font-weight: 600; }
.badge-in { background: #dcfce7; color: #166534; }
.badge-out { background: #fef2f2; color: #dc2626; }
.badge-adj { background: #fef3c7; color: #92400e; }

.empty-state { text-align: center; padding: 2rem !important; color: #9ca3af; }
.empty-state i { font-size: 2rem; margin-bottom: 0.5rem; }

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
