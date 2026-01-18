<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
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
  harga: number
}

interface Supplier {
  id: string
  kode: string
  nama: string
  alamat: string | null
  telepon: string | null
}

interface Branch {
  id: string
  kode: string
  nama: string
}

interface POItem {
  id?: string
  product_id: string
  product?: Product
  qty_ordered: number
  harga_satuan: number
}

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const { logActivity } = useActivityLog()

const isEditMode = computed(() => !!route.params.id)
const poId = computed(() => route.params.id as string)

// Data
const branches = ref<Branch[]>([])
const suppliers = ref<Supplier[]>([])
const products = ref<Product[]>([])
const isLoading = ref(false)
const isSaving = ref(false)
const error = ref<string | null>(null)

// Form
const form = ref({
  po_number: '',
  supplier_id: '',
  branch_id: '',
  tanggal: new Date().toISOString().split('T')[0],
  notes: ''
})
const items = ref<POItem[]>([])

// Product search
const productSearch = ref('')
const showProductDropdown = ref(false)
const activeItemIndex = ref<number | null>(null)

const filteredProducts = computed(() => {
  if (!productSearch.value) return products.value.slice(0, 30)
  const q = productSearch.value.toLowerCase()
  return products.value
    .filter(p => 
      p.kode_barang.toLowerCase().includes(q) ||
      p.nama.toLowerCase().includes(q) ||
      (p.tipe && p.tipe.toLowerCase().includes(q))
    )
    .slice(0, 30)
})

const subtotal = computed(() => {
  return items.value.reduce((sum, item) => sum + (item.qty_ordered * item.harga_satuan), 0)
})

const selectedSupplier = computed(() => {
  return suppliers.value.find(s => s.id === form.value.supplier_id)
})

const selectedBranch = computed(() => {
  return branches.value.find(b => b.id === form.value.branch_id)
})

onMounted(async () => {
  await Promise.all([fetchBranches(), fetchSuppliers(), fetchProducts()])
  await generatePONumber()
  
  if (isEditMode.value) {
    await loadPO()
  }
})

async function fetchBranches() {
  const { data } = await supabase.from('branches').select('*').eq('is_active', true).order('nama')
  branches.value = data || []
}

async function fetchSuppliers() {
  const { data } = await supabase.from('suppliers').select('*').eq('is_active', true).order('nama')
  suppliers.value = data || []
}

async function fetchProducts() {
  const { data } = await supabase
    .from('products')
    .select('id, kode_barang, tipe, kategori, nama, harga')
    .eq('is_active', true)
    .order('kategori')
    .order('kode_barang')
  products.value = data || []
}

async function generatePONumber() {
  const now = new Date()
  const year = now.getFullYear()
  const month = String(now.getMonth() + 1).padStart(2, '0')
  
  const { count } = await supabase
    .from('purchase_orders')
    .select('*', { count: 'exact', head: true })
    .gte('created_at', `${year}-${month}-01`)
  
  const seq = String((count || 0) + 1).padStart(4, '0')
  form.value.po_number = `PO-${year}${month}-${seq}`
}

async function loadPO() {
  isLoading.value = true
  try {
    const { data: po, error: poError } = await supabase
      .from('purchase_orders')
      .select('*')
      .eq('id', poId.value)
      .single()

    if (poError) throw poError

    form.value.po_number = po.po_number
    form.value.supplier_id = po.supplier_id || ''
    form.value.branch_id = po.branch_id
    form.value.tanggal = po.tanggal
    form.value.notes = po.notes || ''

    const { data: poItems, error: itemsError } = await supabase
      .from('purchase_order_items')
      .select('*, product:products(*)')
      .eq('po_id', poId.value)

    if (itemsError) throw itemsError

    items.value = (poItems || []).map(item => ({
      id: item.id,
      product_id: item.product_id,
      product: item.product,
      qty_ordered: item.qty_ordered,
      harga_satuan: item.harga_satuan
    }))
  } catch (err: any) {
    error.value = err.message
  } finally {
    isLoading.value = false
  }
}

function addItem() {
  items.value.push({
    product_id: '',
    qty_ordered: 1,
    harga_satuan: 0
  })
}

function removeItem(index: number) {
  items.value.splice(index, 1)
}

function openProductSearch(index: number) {
  activeItemIndex.value = index
  productSearch.value = ''
  showProductDropdown.value = true
}

function selectProduct(product: Product) {
  if (activeItemIndex.value !== null) {
    items.value[activeItemIndex.value].product_id = product.id
    items.value[activeItemIndex.value].product = product
    items.value[activeItemIndex.value].harga_satuan = product.harga
  }
  showProductDropdown.value = false
  activeItemIndex.value = null
  productSearch.value = ''
}

function closeProductSearch() {
  showProductDropdown.value = false
  activeItemIndex.value = null
  productSearch.value = ''
}

async function handleSave() {
  error.value = null
  
  if (!form.value.supplier_id) {
    error.value = 'Pilih pemasok/principal'
    return
  }
  
  if (!form.value.branch_id) {
    error.value = 'Pilih cabang'
    return
  }
  
  if (items.value.length === 0) {
    error.value = 'Tambahkan minimal 1 item'
    return
  }
  
  const invalidItems = items.value.filter(i => !i.product_id || i.qty_ordered <= 0)
  if (invalidItems.length > 0) {
    error.value = 'Semua item harus memiliki produk dan qty > 0'
    return
  }

  isSaving.value = true
  try {
    if (isEditMode.value) {
      const { error: updateError } = await supabase
        .from('purchase_orders')
        .update({
          supplier_id: form.value.supplier_id,
          branch_id: form.value.branch_id,
          tanggal: form.value.tanggal,
          notes: form.value.notes || null
        })
        .eq('id', poId.value)

      if (updateError) throw updateError

      await supabase.from('purchase_order_items').delete().eq('po_id', poId.value)

      const itemsToInsert = items.value.map(item => ({
        po_id: poId.value,
        product_id: item.product_id,
        qty_ordered: item.qty_ordered,
        harga_satuan: item.harga_satuan
      }))

      const { error: itemsError } = await supabase
        .from('purchase_order_items')
        .insert(itemsToInsert)

      if (itemsError) throw itemsError

      await logActivity({
        module: 'purchase_orders',
        action: 'update',
        entity_id: poId.value,
        entity_name: form.value.po_number,
        description: `Mengupdate PO: ${form.value.po_number}`,
        branch_id: form.value.branch_id
      })
    } else {
      const { data: newPO, error: insertError } = await supabase
        .from('purchase_orders')
        .insert([{
          po_number: form.value.po_number,
          supplier_id: form.value.supplier_id,
          branch_id: form.value.branch_id,
          tanggal: form.value.tanggal,
          notes: form.value.notes || null,
          status: 'draft',
          created_by: authStore.user?.id
        }])
        .select()
        .single()

      if (insertError) throw insertError

      const itemsToInsert = items.value.map(item => ({
        po_id: newPO.id,
        product_id: item.product_id,
        qty_ordered: item.qty_ordered,
        harga_satuan: item.harga_satuan
      }))

      const { error: itemsError } = await supabase
        .from('purchase_order_items')
        .insert(itemsToInsert)

      if (itemsError) throw itemsError

      await logActivity({
        module: 'purchase_orders',
        action: 'create',
        entity_id: newPO.id,
        entity_name: form.value.po_number,
        description: `Membuat PO baru: ${form.value.po_number} ke ${selectedSupplier.value?.nama}`,
        branch_id: form.value.branch_id
      })
    }

    router.push('/pembelian')
  } catch (err: any) {
    error.value = err.message
  } finally {
    isSaving.value = false
  }
}

function printPO() {
  window.print()
}

function formatCurrency(value: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(value)
}

function formatDate(dateStr: string) {
  return new Date(dateStr).toLocaleDateString('id-ID', { day: '2-digit', month: 'long', year: 'numeric' })
}

function goBack() {
  router.push('/pembelian')
}
</script>

<template>
  <div class="po-form-view">
    <!-- Header (hide on print) -->
    <div class="view-header no-print">
      <div class="header-left">
        <button @click="goBack" class="btn-back">
          <i class="pi pi-arrow-left"></i>
        </button>
        <div>
          <h2>{{ isEditMode ? 'Edit Purchase Order' : 'Buat Purchase Order' }}</h2>
          <p>{{ form.po_number }}</p>
        </div>
      </div>
      <div class="header-actions">
        <button @click="printPO" class="btn-outline" v-if="items.length > 0">
          <i class="pi pi-print"></i>
          Print / PDF
        </button>
        <button @click="goBack" class="btn-secondary">Batal</button>
        <button @click="handleSave" class="btn-primary" :disabled="isSaving">
          <i v-if="isSaving" class="pi pi-spin pi-spinner"></i>
          {{ isEditMode ? 'Simpan Perubahan' : 'Simpan PO' }}
        </button>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="isLoading" class="loading-state no-print">
      <i class="pi pi-spin pi-spinner"></i>
      <span>Memuat data...</span>
    </div>

    <!-- Form -->
    <div v-else class="form-container">
      <!-- Error -->
      <div v-if="error" class="error-alert no-print">
        <i class="pi pi-exclamation-circle"></i>
        {{ error }}
      </div>

      <!-- Print Header (show only on print) -->
      <div class="print-header print-only">
        <h1>PURCHASE ORDER</h1>
        <p class="po-number">{{ form.po_number }}</p>
      </div>

      <!-- PO Info -->
      <div class="form-card">
        <h3 class="no-print">Informasi Purchase Order</h3>
        <div class="form-grid">
          <div class="form-group">
            <label>Pemasok / Principal <span class="required">*</span></label>
            <select v-model="form.supplier_id" class="form-input no-print">
              <option value="">Pilih Pemasok</option>
              <option v-for="s in suppliers" :key="s.id" :value="s.id">{{ s.nama }}</option>
            </select>
            <div class="print-only print-value">{{ selectedSupplier?.nama || '-' }}</div>
            <div v-if="selectedSupplier" class="supplier-info">
              <small>{{ selectedSupplier.alamat || '' }}</small>
              <small v-if="selectedSupplier.telepon">Tel: {{ selectedSupplier.telepon }}</small>
            </div>
          </div>
          <div class="form-group">
            <label>Cabang Tujuan <span class="required">*</span></label>
            <select v-model="form.branch_id" class="form-input no-print">
              <option value="">Pilih Cabang</option>
              <option v-for="b in branches" :key="b.id" :value="b.id">{{ b.nama }}</option>
            </select>
            <div class="print-only print-value">{{ selectedBranch?.nama || '-' }}</div>
          </div>
          <div class="form-group">
            <label>Tanggal <span class="required">*</span></label>
            <input v-model="form.tanggal" type="date" class="form-input no-print" />
            <div class="print-only print-value">{{ formatDate(form.tanggal) }}</div>
          </div>
          <div class="form-group">
            <label>No. PO</label>
            <div class="print-value">{{ form.po_number }}</div>
          </div>
          <div class="form-group col-span-2">
            <label>Catatan</label>
            <textarea v-model="form.notes" class="form-input no-print" rows="2" placeholder="Catatan opsional..."></textarea>
            <div class="print-only print-value" v-if="form.notes">{{ form.notes }}</div>
          </div>
        </div>
      </div>

      <!-- Items -->
      <div class="form-card">
        <div class="card-header no-print">
          <h3>Item Pesanan</h3>
          <button @click="addItem" class="btn-outline">
            <i class="pi pi-plus"></i>
            Tambah Item
          </button>
        </div>
        <h3 class="print-only">Item Pesanan</h3>

        <!-- Items Table -->
        <table class="items-table">
          <thead>
            <tr>
              <th style="width: 50px">#</th>
              <th>Kode</th>
              <th>Nama Barang</th>
              <th style="width: 100px">Qty</th>
              <th style="width: 160px">Harga Satuan</th>
              <th style="width: 160px">Subtotal</th>
              <th style="width: 60px" class="no-print"></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(item, index) in items" :key="index">
              <td class="text-center text-muted">{{ index + 1 }}</td>
              <td>
                <span v-if="item.product">{{ item.product.kode_barang }}</span>
                <span v-else class="text-muted">-</span>
              </td>
              <td>
                <!-- Product Search Input (hide on print) -->
                <div class="product-select no-print">
                  <div 
                    v-if="item.product" 
                    class="selected-product"
                    @click="openProductSearch(index)"
                  >
                    <span class="product-name">{{ item.product.nama }}</span>
                    <i class="pi pi-chevron-down"></i>
                  </div>
                  <button 
                    v-else 
                    @click="openProductSearch(index)"
                    class="select-product-btn"
                  >
                    <i class="pi pi-search"></i>
                    Pilih Produk
                  </button>
                </div>
                <!-- Print version -->
                <span class="print-only">{{ item.product?.nama || '-' }}</span>
              </td>
              <td>
                <input 
                  v-model.number="item.qty_ordered" 
                  type="number" 
                  class="form-input text-center no-print" 
                  min="1"
                />
                <span class="print-only">{{ item.qty_ordered }}</span>
              </td>
              <td>
                <input 
                  v-model.number="item.harga_satuan" 
                  type="number" 
                  class="form-input text-right no-print" 
                  min="0"
                />
                <span class="print-only text-right">{{ formatCurrency(item.harga_satuan) }}</span>
              </td>
              <td class="text-right font-medium">
                {{ formatCurrency(item.qty_ordered * item.harga_satuan) }}
              </td>
              <td class="text-center no-print">
                <button @click="removeItem(index)" class="btn-icon btn-danger" title="Hapus">
                  <i class="pi pi-trash"></i>
                </button>
              </td>
            </tr>
            <tr v-if="items.length === 0">
              <td colspan="7" class="empty-state no-print">
                <p>Belum ada item. Klik "Tambah Item" untuk menambahkan.</p>
              </td>
            </tr>
          </tbody>
          <tfoot v-if="items.length > 0">
            <tr>
              <td colspan="5" class="text-right font-medium">Total:</td>
              <td class="text-right font-bold">{{ formatCurrency(subtotal) }}</td>
              <td class="no-print"></td>
            </tr>
          </tfoot>
        </table>
      </div>

      <!-- Print Footer -->
      <div class="print-footer print-only">
        <div class="signature-area">
          <div class="signature-box">
            <p>Dibuat oleh,</p>
            <div class="signature-line"></div>
            <p>{{ authStore.userName }}</p>
          </div>
          <div class="signature-box">
            <p>Disetujui oleh,</p>
            <div class="signature-line"></div>
            <p>______________________</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Product Search Modal -->
    <div v-if="showProductDropdown" class="modal-overlay no-print" @click.self="closeProductSearch">
      <div class="search-modal">
        <div class="search-header">
          <h3>Cari Produk</h3>
          <button @click="closeProductSearch" class="btn-close">
            <i class="pi pi-times"></i>
          </button>
        </div>
        <div class="search-input-wrapper">
          <i class="pi pi-search"></i>
          <input 
            v-model="productSearch" 
            type="text" 
            placeholder="Ketik kode, nama, atau tipe produk..."
            class="search-input"
            autofocus
            @keydown.enter="filteredProducts.length > 0 && selectProduct(filteredProducts[0])"
          />
        </div>
        <div class="search-results">
          <div 
            v-for="product in filteredProducts" 
            :key="product.id"
            @click="selectProduct(product)"
            class="product-item"
          >
            <div class="product-item-info">
              <span class="product-item-code">{{ product.kode_barang }}</span>
              <span class="product-item-badge" :class="product.kategori === 'AMB' ? 'badge-amb' : 'badge-mcb'">
                {{ product.kategori }}
              </span>
            </div>
            <div class="product-item-name">{{ product.nama }}</div>
            <div class="product-item-details">
              <span class="product-item-type">{{ product.tipe || '-' }}</span>
              <span class="product-item-price">{{ formatCurrency(product.harga) }}</span>
            </div>
          </div>
          <div v-if="filteredProducts.length === 0" class="no-results">
            <i class="pi pi-search"></i>
            <p>Tidak ada produk ditemukan</p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.po-form-view { max-width: 1000px; }

.view-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem; flex-wrap: wrap; gap: 1rem; }
.header-left { display: flex; align-items: center; gap: 1rem; }
.view-header h2 { font-size: 1.5rem; font-weight: 700; color: #1f2937; margin-bottom: 0.25rem; }
.view-header p { color: #6b7280; font-size: 0.875rem; font-family: monospace; }

.btn-back { width: 40px; height: 40px; display: flex; align-items: center; justify-content: center; border: none; border-radius: 8px; background: #f3f4f6; color: #6b7280; cursor: pointer; }
.btn-back:hover { background: #e5e7eb; color: #374151; }

.header-actions { display: flex; gap: 0.75rem; }

.btn-primary { display: inline-flex; align-items: center; gap: 0.5rem; padding: 0.75rem 1.5rem; background: linear-gradient(135deg, #FE0000, #cc0000); color: white; border: none; border-radius: 8px; font-weight: 600; font-size: 0.875rem; cursor: pointer; }
.btn-primary:hover:not(:disabled) { transform: translateY(-1px); box-shadow: 0 4px 12px rgba(254, 0, 0, 0.3); }
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }

.btn-secondary { padding: 0.75rem 1.5rem; background: #f3f4f6; color: #374151; border: none; border-radius: 8px; font-weight: 600; font-size: 0.875rem; cursor: pointer; }

.btn-outline { display: inline-flex; align-items: center; gap: 0.5rem; padding: 0.5rem 1rem; border: 2px solid #254060; background: transparent; color: #254060; border-radius: 8px; font-weight: 600; font-size: 0.8125rem; cursor: pointer; }
.btn-outline:hover { background: #254060; color: white; }

.loading-state { display: flex; align-items: center; justify-content: center; gap: 0.75rem; padding: 3rem; color: #6b7280; }

.form-container { display: flex; flex-direction: column; gap: 1.5rem; }

.error-alert { display: flex; align-items: center; gap: 0.5rem; padding: 1rem; border-radius: 8px; background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; }

.form-card { background: white; border-radius: 12px; padding: 1.5rem; box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1); }
.form-card h3 { font-size: 1rem; font-weight: 600; color: #1f2937; margin-bottom: 1rem; }

.card-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; }

.form-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 1rem; }
.col-span-2 { grid-column: span 2; }

.form-group label { display: block; font-size: 0.8125rem; font-weight: 500; color: #374151; margin-bottom: 0.375rem; }
.required { color: #dc2626; }
.form-input { width: 100%; padding: 0.625rem 0.875rem; border: 1px solid #e5e7eb; border-radius: 6px; font-size: 0.875rem; }
.form-input:focus { outline: none; border-color: #254060; }

.print-value { font-size: 0.875rem; font-weight: 500; color: #1f2937; padding: 0.625rem 0; }

.supplier-info { margin-top: 0.25rem; display: flex; flex-direction: column; gap: 0.125rem; }
.supplier-info small { color: #6b7280; font-size: 0.75rem; }

/* Items Table */
.items-table { width: 100%; border-collapse: collapse; margin-top: 0.5rem; }
.items-table th { padding: 0.75rem; text-align: left; font-size: 0.6875rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; color: #6b7280; background: #f9fafb; border-bottom: 1px solid #e5e7eb; }
.items-table td { padding: 0.75rem; font-size: 0.875rem; border-bottom: 1px solid #e5e7eb; vertical-align: middle; }
.items-table tfoot td { padding: 1rem 0.75rem; background: #f9fafb; font-size: 1rem; }

.text-center { text-align: center; }
.text-right { text-align: right; }
.text-muted { color: #9ca3af; }
.font-medium { font-weight: 500; }
.font-bold { font-weight: 700; color: #1f2937; }

/* Product Select */
.product-select { width: 100%; }

.selected-product { display: flex; align-items: center; gap: 0.5rem; padding: 0.5rem 0.75rem; background: #f3f4f6; border-radius: 6px; cursor: pointer; }
.selected-product:hover { background: #e5e7eb; }
.product-name { flex: 1; color: #374151; font-size: 0.8125rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.selected-product i { color: #9ca3af; font-size: 0.75rem; }

.select-product-btn { width: 100%; display: flex; align-items: center; justify-content: center; gap: 0.5rem; padding: 0.625rem; border: 2px dashed #d1d5db; background: transparent; border-radius: 6px; color: #6b7280; font-size: 0.8125rem; cursor: pointer; }
.select-product-btn:hover { border-color: #254060; color: #254060; }

.btn-icon { width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; border: none; border-radius: 6px; background: #f3f4f6; color: #6b7280; cursor: pointer; }
.btn-icon.btn-danger { background: #fef2f2; color: #dc2626; }
.btn-icon.btn-danger:hover { background: #fee2e2; }

.empty-state { text-align: center; padding: 2rem !important; color: #9ca3af; }

/* Search Modal */
.modal-overlay { position: fixed; inset: 0; background: rgba(0, 0, 0, 0.5); display: flex; align-items: flex-start; justify-content: center; z-index: 100; padding: 5vh 1rem; }

.search-modal { background: white; border-radius: 12px; width: 100%; max-width: 600px; max-height: 80vh; display: flex; flex-direction: column; overflow: hidden; box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3); }

.search-header { display: flex; justify-content: space-between; align-items: center; padding: 1rem 1.25rem; border-bottom: 1px solid #e5e7eb; }
.search-header h3 { font-size: 1rem; font-weight: 600; color: #1f2937; }
.btn-close { width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; border: none; border-radius: 6px; background: transparent; color: #6b7280; cursor: pointer; }

.search-input-wrapper { display: flex; align-items: center; gap: 0.75rem; padding: 1rem 1.25rem; border-bottom: 1px solid #e5e7eb; background: #f9fafb; }
.search-input-wrapper i { color: #9ca3af; }
.search-input { flex: 1; border: none; background: transparent; font-size: 1rem; outline: none; }

.search-results { flex: 1; overflow-y: auto; max-height: 400px; }

.product-item { padding: 0.875rem 1.25rem; cursor: pointer; border-bottom: 1px solid #f3f4f6; }
.product-item:hover { background: #f9fafb; }
.product-item-info { display: flex; align-items: center; gap: 0.5rem; margin-bottom: 0.25rem; }
.product-item-code { font-weight: 600; color: #254060; font-size: 0.875rem; }
.product-item-badge { padding: 0.125rem 0.375rem; border-radius: 4px; font-size: 0.625rem; font-weight: 700; }
.badge-amb { background: #dbeafe; color: #1e40af; }
.badge-mcb { background: #dcfce7; color: #166534; }
.product-item-name { font-size: 0.875rem; color: #374151; margin-bottom: 0.25rem; }
.product-item-details { display: flex; justify-content: space-between; }
.product-item-type { font-size: 0.75rem; color: #9ca3af; }
.product-item-price { font-size: 0.75rem; color: #6b7280; font-weight: 500; }

.no-results { text-align: center; padding: 2rem; color: #9ca3af; }
.no-results i { font-size: 2rem; margin-bottom: 0.5rem; }

/* Print Styles */
.print-only { display: none; }

@media print {
  .no-print { display: none !important; }
  .print-only { display: block; }
  
  .po-form-view { max-width: 100%; padding: 0; }
  .form-card { box-shadow: none; border: 1px solid #e5e7eb; page-break-inside: avoid; }
  
  .print-header { text-align: center; margin-bottom: 2rem; }
  .print-header h1 { font-size: 1.5rem; font-weight: 700; margin-bottom: 0.5rem; }
  .print-header .po-number { font-size: 1rem; font-family: monospace; }
  
  .items-table { font-size: 0.8rem; }
  .items-table th, .items-table td { padding: 0.5rem; }
  
  .print-footer { margin-top: 3rem; }
  .signature-area { display: flex; justify-content: space-between; gap: 2rem; }
  .signature-box { flex: 1; text-align: center; }
  .signature-box p { font-size: 0.875rem; margin: 0.5rem 0; }
  .signature-line { border-bottom: 1px solid #000; height: 60px; margin: 1rem 0; }
}
</style>
