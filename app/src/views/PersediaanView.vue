<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabaseClient'
import { useActivityLog } from '../composables/useActivityLog'
import ActivityPanel from '../components/ActivityPanel.vue'

const router = useRouter()
const { logs, isLoading: logsLoading, logActivity, fetchLogs } = useActivityLog()

interface Product {
  id: string
  kode_barang: string
  tipe: string | null
  kategori: 'AMB' | 'MCB'
  nama: string
  deskripsi: string | null
  harga: number
  stock: number
  satuan: string
  is_active: boolean
}

interface Branch {
  id: string
  kode: string
  nama: string
}

const products = ref<Product[]>([])
const branches = ref<Branch[]>([])
const selectedBranch = ref<string>('')
const isLoading = ref(false)
const error = ref<string | null>(null)

// Modal
const showModal = ref(false)
const modalMode = ref<'add' | 'edit'>('add')
const editingProduct = ref<Product | null>(null)

// Search & Filter
const searchQuery = ref('')
const filterCategory = ref<'all' | 'AMB' | 'MCB'>('all')

// Form - stock tidak dikelola disini, tapi dari detail produk (mutasi)
const form = ref({
  kode_barang: '',
  tipe: '',
  kategori: 'AMB' as 'AMB' | 'MCB',
  nama: '',
  deskripsi: '',
  harga: 0,
  satuan: 'PCS'
})
const formError = ref('')
const isSaving = ref(false)

// Delete confirmation
const showDeleteConfirm = ref(false)
const productToDelete = ref<Product | null>(null)

// Filtered products
const filteredProducts = computed(() => {
  let result = products.value
  
  if (filterCategory.value !== 'all') {
    result = result.filter(p => p.kategori === filterCategory.value)
  }
  
  if (searchQuery.value) {
    const query = searchQuery.value.toLowerCase()
    result = result.filter(p => 
      p.kode_barang.toLowerCase().includes(query) ||
      p.nama.toLowerCase().includes(query) ||
      (p.tipe && p.tipe.toLowerCase().includes(query))
    )
  }
  
  return result
})

onMounted(async () => {
  await fetchBranches()
  await fetchLogs('products')
})

watch(selectedBranch, () => {
  if (selectedBranch.value) {
    fetchProducts()
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
  isLoading.value = true
  error.value = null
  try {
    // Get products
    const { data: productsData, error: fetchError } = await supabase
      .from('products')
      .select('*')
      .eq('is_active', true)
      .order('kategori')
      .order('kode_barang')
    
    if (fetchError) throw fetchError

    // Get stocks for selected branch
    const { data: stocksData } = await supabase
      .from('product_stocks')
      .select('product_id, stock')
      .eq('branch_id', selectedBranch.value)

    // Combine data
    const stockMap = new Map((stocksData || []).map(s => [s.product_id, s.stock]))
    products.value = (productsData || []).map(p => ({
      ...p,
      stock: stockMap.get(p.id) || 0
    }))
  } catch (err: any) {
    error.value = err.message
  } finally {
    isLoading.value = false
  }
}

function openAddModal() {
  if (!selectedBranch.value) {
    error.value = 'Pilih cabang terlebih dahulu'
    return
  }
  modalMode.value = 'add'
  form.value = { kode_barang: '', tipe: '', kategori: 'AMB', nama: '', deskripsi: '', harga: 0, satuan: 'PCS' }
  formError.value = ''
  showModal.value = true
}

function openEditModal(product: Product) {
  modalMode.value = 'edit'
  editingProduct.value = product
  form.value = {
    kode_barang: product.kode_barang,
    tipe: product.tipe || '',
    kategori: product.kategori,
    nama: product.nama,
    deskripsi: product.deskripsi || '',
    harga: product.harga,
    satuan: product.satuan
  }
  formError.value = ''
  showModal.value = true
}

function closeModal() {
  showModal.value = false
  editingProduct.value = null
}

async function handleSubmit() {
  formError.value = ''
  
  if (!form.value.kode_barang || !form.value.nama) {
    formError.value = 'Kode barang dan nama wajib diisi'
    return
  }

  isSaving.value = true
  try {
    if (modalMode.value === 'add') {
      const { data: newProduct, error: insertError } = await supabase
        .from('products')
        .insert([form.value])
        .select()
        .single()
      
      if (insertError) throw insertError
      
      // Log activity
      await logActivity({
        module: 'products',
        action: 'create',
        entity_id: newProduct?.id,
        entity_name: form.value.kode_barang,
        description: `Membuat produk baru: ${form.value.nama} (${form.value.kode_barang})`,
        new_value: form.value,
        branch_id: selectedBranch.value
      })
    } else if (editingProduct.value) {
      const { error: updateError } = await supabase
        .from('products')
        .update(form.value)
        .eq('id', editingProduct.value.id)
      
      if (updateError) throw updateError
      
      // Log activity
      await logActivity({
        module: 'products',
        action: 'update',
        entity_id: editingProduct.value.id,
        entity_name: form.value.kode_barang,
        description: `Mengupdate produk: ${form.value.nama}`,
        old_value: editingProduct.value as unknown as Record<string, unknown>,
        new_value: form.value as unknown as Record<string, unknown>,
        branch_id: selectedBranch.value
      })
    }
    
    await fetchProducts()
    await fetchLogs('products')
    closeModal()
  } catch (err: any) {
    formError.value = err.message
  } finally {
    isSaving.value = false
  }
}

function confirmDelete(product: Product) {
  productToDelete.value = product
  showDeleteConfirm.value = true
}

async function handleDelete() {
  if (!productToDelete.value) return
  
  try {
    const { error: deleteError } = await supabase
      .from('products')
      .update({ is_active: false })
      .eq('id', productToDelete.value.id)
    
    if (deleteError) throw deleteError
    
    // Log activity
    await logActivity({
      module: 'products',
      action: 'delete',
      entity_id: productToDelete.value.id,
      entity_name: productToDelete.value.kode_barang,
      description: `Menghapus produk: ${productToDelete.value.nama}`,
      branch_id: selectedBranch.value
    })
    
    await fetchProducts()
    await fetchLogs('products')
    showDeleteConfirm.value = false
    productToDelete.value = null
  } catch (err: any) {
    error.value = err.message
  }
}

function formatCurrency(value: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(value)
}

function viewDetail(product: Product) {
  router.push(`/persediaan/${product.id}`)
}
</script>

<template>
  <div class="page-with-activity">
    <div class="main-content">
      <div class="persediaan-view">
    <!-- Header -->
    <div class="view-header">
      <div>
        <h2>Daftar Barang</h2>
        <p>Kelola data persediaan barang</p>
      </div>
      <div class="header-actions">
        <!-- Branch Selector -->
        <select v-model="selectedBranch" class="branch-select">
          <option value="" disabled>Pilih Cabang</option>
          <option v-for="b in branches" :key="b.id" :value="b.id">{{ b.nama }}</option>
        </select>
        <button @click="openAddModal" class="btn-primary" :disabled="!selectedBranch">
          <i class="pi pi-plus"></i>
          Tambah Barang
        </button>
      </div>
    </div>

    <!-- Filters -->
    <div class="filters-row">
      <div class="search-bar">
        <i class="pi pi-search"></i>
        <input v-model="searchQuery" type="text" placeholder="Cari kode, nama, atau tipe..." />
      </div>
      <div class="category-tabs">
        <button 
          @click="filterCategory = 'all'" 
          :class="{ active: filterCategory === 'all' }"
        >Semua</button>
        <button 
          @click="filterCategory = 'AMB'" 
          :class="{ active: filterCategory === 'AMB' }"
        >AMB (Aki Mobil)</button>
        <button 
          @click="filterCategory = 'MCB'" 
          :class="{ active: filterCategory === 'MCB' }"
        >MCB (Aki Motor)</button>
      </div>
    </div>

    <!-- Error -->
    <div v-if="error" class="error-alert">
      <i class="pi pi-exclamation-circle"></i>
      {{ error }}
    </div>

    <!-- No Branch Selected -->
    <div v-if="!selectedBranch" class="info-alert">
      <i class="pi pi-info-circle"></i>
      Pilih cabang untuk melihat data persediaan
    </div>

    <!-- Loading -->
    <div v-else-if="isLoading" class="loading-state">
      <i class="pi pi-spin pi-spinner"></i>
      <span>Memuat data...</span>
    </div>

    <!-- Table -->
    <div v-else class="table-card">
      <table class="data-table">
        <thead>
          <tr>
            <th>Kategori</th>
            <th>Kode Barang</th>
            <th>Tipe</th>
            <th>Nama Barang</th>
            <th>Harga</th>
            <th>Stock</th>
            <th>Satuan</th>
            <th>Aksi</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="product in filteredProducts" :key="product.id">
            <td>
              <span class="category-badge" :class="product.kategori === 'AMB' ? 'cat-amb' : 'cat-mcb'">
                {{ product.kategori }}
              </span>
            </td>
            <td class="font-medium">{{ product.kode_barang }}</td>
            <td>{{ product.tipe || '-' }}</td>
            <td>
              <a @click="viewDetail(product)" class="product-link">{{ product.nama }}</a>
            </td>
            <td>{{ formatCurrency(product.harga) }}</td>
            <td>
              <span :class="product.stock < 10 ? 'text-red' : ''">
                {{ product.stock.toLocaleString() }}
              </span>
            </td>
            <td>{{ product.satuan }}</td>
            <td>
              <div class="action-buttons">
                <button @click="viewDetail(product)" class="btn-icon btn-view" title="Detail & Stock">
                  <i class="pi pi-eye"></i>
                </button>
                <button @click="openEditModal(product)" class="btn-icon" title="Edit">
                  <i class="pi pi-pencil"></i>
                </button>
                <button @click="confirmDelete(product)" class="btn-icon btn-danger" title="Hapus">
                  <i class="pi pi-trash"></i>
                </button>
              </div>
            </td>
          </tr>
          <tr v-if="filteredProducts.length === 0">
            <td colspan="8" class="empty-state">
              <i class="pi pi-box"></i>
              <p>{{ searchQuery || filterCategory !== 'all' ? 'Tidak ada hasil' : 'Belum ada data barang' }}</p>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Add/Edit Modal -->
    <div v-if="showModal" class="modal-overlay" @click.self="closeModal">
      <div class="modal-content modal-lg">
        <div class="modal-header">
          <h3>{{ modalMode === 'add' ? 'Tambah Barang' : 'Edit Barang' }}</h3>
          <button @click="closeModal" class="btn-close"><i class="pi pi-times"></i></button>
        </div>

        <form @submit.prevent="handleSubmit" class="modal-form">
          <div class="form-grid">
            <div class="form-group">
              <label>Kategori <span class="required">*</span></label>
              <select v-model="form.kategori" class="form-input">
                <option value="AMB">AMB (Aki Mobil)</option>
                <option value="MCB">MCB (Aki Motor)</option>
              </select>
            </div>

            <div class="form-group">
              <label>Kode Barang <span class="required">*</span></label>
              <input v-model="form.kode_barang" type="text" class="form-input" :disabled="modalMode === 'edit'" />
            </div>

            <div class="form-group">
              <label>Tipe</label>
              <input v-model="form.tipe" type="text" class="form-input" placeholder="NS-40-ZL, YTZ5S, dll" />
            </div>

            <div class="form-group">
              <label>Nama Barang <span class="required">*</span></label>
              <input v-model="form.nama" type="text" class="form-input" />
            </div>

            <div class="form-group col-span-2">
              <label>Deskripsi</label>
              <textarea v-model="form.deskripsi" class="form-input" rows="2"></textarea>
            </div>

            <div class="form-group">
              <label>Harga</label>
              <input v-model.number="form.harga" type="number" class="form-input" min="0" />
            </div>

            <div class="form-group">
              <label>Satuan</label>
              <select v-model="form.satuan" class="form-input">
                <option value="PCS">PCS</option>
                <option value="BOX">BOX</option>
                <option value="SET">SET</option>
              </select>
            </div>
          </div>

          <div v-if="formError" class="form-error">
            <i class="pi pi-exclamation-circle"></i>
            {{ formError }}
          </div>

          <div class="modal-actions">
            <button type="button" @click="closeModal" class="btn-secondary">Batal</button>
            <button type="submit" class="btn-primary" :disabled="isSaving">
              <i v-if="isSaving" class="pi pi-spin pi-spinner"></i>
              {{ modalMode === 'add' ? 'Tambah' : 'Simpan' }}
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- Delete Confirmation -->
    <div v-if="showDeleteConfirm" class="modal-overlay" @click.self="showDeleteConfirm = false">
      <div class="modal-content modal-small">
        <div class="modal-header"><h3>Konfirmasi Hapus</h3></div>
        <div class="modal-body"><p>Hapus barang <strong>{{ productToDelete?.nama }}</strong>?</p></div>
        <div class="modal-actions">
          <button @click="showDeleteConfirm = false" class="btn-secondary">Batal</button>
          <button @click="handleDelete" class="btn-danger">Hapus</button>
        </div>
      </div>
    </div>
      </div>
    </div>

    <!-- Activity Panel -->
    <ActivityPanel 
      :logs="logs" 
      :is-loading="logsLoading"
      title="Aktivitas Persediaan"
    />
  </div>
</template>

<style scoped>
/* Page with Activity Layout */
.page-with-activity {
  display: grid;
  grid-template-columns: 1fr 320px;
  gap: 1.5rem;
  align-items: start;
}

@media (max-width: 1024px) {
  .page-with-activity {
    grid-template-columns: 1fr;
  }
}

.main-content {
  min-width: 0;
}

.persediaan-view { max-width: 100%; }

.view-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; flex-wrap: wrap; gap: 1rem; }
.view-header h2 { font-size: 1.5rem; font-weight: 700; color: #1f2937; margin-bottom: 0.25rem; }
.view-header p { color: #6b7280; font-size: 0.875rem; }

.header-actions { display: flex; gap: 0.75rem; align-items: center; }

.branch-select {
  padding: 0.625rem 1rem;
  border: 2px solid #254060;
  border-radius: 8px;
  font-size: 0.875rem;
  font-weight: 500;
  min-width: 180px;
  background: white;
}

.btn-primary { display: inline-flex; align-items: center; gap: 0.5rem; padding: 0.75rem 1.25rem; background: linear-gradient(135deg, #FE0000, #cc0000); color: white; border: none; border-radius: 8px; font-weight: 600; font-size: 0.875rem; cursor: pointer; }
.btn-primary:hover:not(:disabled) { transform: translateY(-1px); box-shadow: 0 4px 12px rgba(254, 0, 0, 0.3); }
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }

.filters-row { display: flex; gap: 1rem; margin-bottom: 1rem; flex-wrap: wrap; }

.search-bar { display: flex; align-items: center; gap: 0.75rem; padding: 0.625rem 1rem; background: white; border-radius: 8px; border: 1px solid #e5e7eb; flex: 1; min-width: 200px; }
.search-bar i { color: #9ca3af; }
.search-bar input { flex: 1; border: none; font-size: 0.875rem; outline: none; }

.category-tabs { display: flex; gap: 0.25rem; background: white; padding: 0.25rem; border-radius: 8px; border: 1px solid #e5e7eb; }
.category-tabs button { padding: 0.5rem 1rem; border: none; background: transparent; font-size: 0.8125rem; font-weight: 500; border-radius: 6px; cursor: pointer; color: #6b7280; }
.category-tabs button.active { background: #254060; color: white; }
.category-tabs button:hover:not(.active) { background: #f3f4f6; }

.error-alert, .info-alert { display: flex; align-items: center; gap: 0.5rem; padding: 1rem; border-radius: 8px; margin-bottom: 1rem; }
.error-alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; }
.info-alert { background: #eff6ff; border: 1px solid #bfdbfe; color: #1e40af; }

.loading-state { display: flex; align-items: center; justify-content: center; gap: 0.75rem; padding: 3rem; color: #6b7280; }

.table-card { background: white; border-radius: 12px; box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1); overflow: hidden; }

.data-table { width: 100%; border-collapse: collapse; }
.data-table th { padding: 0.875rem 1rem; text-align: left; font-size: 0.6875rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; color: #6b7280; background: #f9fafb; border-bottom: 1px solid #e5e7eb; }
.data-table td { padding: 0.875rem 1rem; font-size: 0.8125rem; border-bottom: 1px solid #e5e7eb; }

.font-medium { font-weight: 500; }
.text-red { color: #dc2626; font-weight: 600; }

.category-badge { display: inline-block; padding: 0.25rem 0.625rem; border-radius: 4px; font-size: 0.6875rem; font-weight: 700; }
.cat-amb { background: #dbeafe; color: #1e40af; }
.cat-mcb { background: #dcfce7; color: #166534; }

.product-link { color: #254060; font-weight: 500; cursor: pointer; text-decoration: none; }
.product-link:hover { color: #FE0000; text-decoration: underline; }

.action-buttons { display: flex; gap: 0.5rem; }
.btn-icon { width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; border: none; border-radius: 6px; background: #f3f4f6; color: #6b7280; cursor: pointer; }
.btn-icon:hover { background: #e5e7eb; color: #374151; }
.btn-icon.btn-view { background: #eff6ff; color: #1e40af; }
.btn-icon.btn-view:hover { background: #dbeafe; color: #1e40af; }
.btn-icon.btn-danger { background: #fef2f2; color: #dc2626; }

.empty-state { text-align: center; padding: 2rem !important; color: #9ca3af; }
.empty-state i { font-size: 2rem; margin-bottom: 0.5rem; }

/* Modal */
.modal-overlay { position: fixed; inset: 0; background: rgba(0, 0, 0, 0.5); display: flex; align-items: center; justify-content: center; z-index: 100; padding: 1rem; }
.modal-content { background: white; border-radius: 12px; width: 100%; max-width: 480px; }
.modal-lg { max-width: 600px; }
.modal-small { max-width: 400px; }
.modal-header { display: flex; justify-content: space-between; align-items: center; padding: 1.25rem 1.5rem; border-bottom: 1px solid #e5e7eb; }
.modal-header h3 { font-size: 1.125rem; font-weight: 600; color: #1f2937; }
.btn-close { width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; border: none; border-radius: 6px; background: transparent; color: #6b7280; cursor: pointer; }
.modal-body { padding: 1.5rem; }
.modal-form { padding: 1.5rem; }

.form-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 1rem; }
.col-span-2 { grid-column: span 2; }
.form-group label { display: block; font-size: 0.8125rem; font-weight: 500; color: #374151; margin-bottom: 0.375rem; }
.required { color: #dc2626; }
.form-input { width: 100%; padding: 0.625rem 0.875rem; border: 1px solid #e5e7eb; border-radius: 6px; font-size: 0.875rem; }
.form-input:focus { outline: none; border-color: #254060; }
.form-input:disabled { background: #f9fafb; color: #6b7280; }

.form-error { display: flex; align-items: center; gap: 0.5rem; padding: 0.75rem; background: #fef2f2; border-radius: 6px; color: #dc2626; font-size: 0.8125rem; margin-top: 1rem; }

.modal-actions { display: flex; justify-content: flex-end; gap: 0.75rem; padding: 1rem 1.5rem; border-top: 1px solid #e5e7eb; }
.btn-secondary { padding: 0.75rem 1.25rem; background: #f3f4f6; color: #374151; border: none; border-radius: 8px; font-weight: 600; cursor: pointer; }
.btn-danger { padding: 0.75rem 1.25rem; background: #dc2626; color: white; border: none; border-radius: 8px; font-weight: 600; cursor: pointer; }
</style>
