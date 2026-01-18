<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { supabase } from '../lib/supabaseClient'

// Stats
const stats = ref({
  totalProducts: 0,
  totalStock: 0,
  pendingPO: 0,
  monthlySales: 0
})

const recentPO = ref<any[]>([])
const topProducts = ref<any[]>([])
const isLoading = ref(true)

onMounted(async () => {
  await fetchDashboardData()
})

async function fetchDashboardData() {
  isLoading.value = true
  try {
    // Get products count & total stock
    const { data: products } = await supabase
      .from('products')
      .select('id, stock')
      .eq('is_active', true)
    
    if (products) {
      stats.value.totalProducts = products.length
      stats.value.totalStock = products.reduce((sum, p) => sum + (p.stock || 0), 0)
    }

    // Get pending PO count
    const { count: poCount } = await supabase
      .from('purchase_orders')
      .select('id', { count: 'exact' })
      .in('status', ['draft', 'pending', 'approved'])
    
    stats.value.pendingPO = poCount || 0

    // Get this month sales
    const firstDayOfMonth = new Date()
    firstDayOfMonth.setDate(1)
    const { data: salesData } = await supabase
      .from('sales')
      .select('qty_sold')
      .gte('bulan_tahun', firstDayOfMonth.toISOString().split('T')[0])
    
    if (salesData) {
      stats.value.monthlySales = salesData.reduce((sum, s) => sum + (s.qty_sold || 0), 0)
    }

    // Get recent POs
    const { data: poData } = await supabase
      .from('purchase_orders')
      .select(`
        *,
        branches (nama)
      `)
      .order('created_at', { ascending: false })
      .limit(5)
    
    recentPO.value = poData || []

    // Get top products by stock
    const { data: topProductsData } = await supabase
      .from('products')
      .select('kode_barang, nama, stock, harga')
      .eq('is_active', true)
      .order('stock', { ascending: false })
      .limit(5)
    
    topProducts.value = topProductsData || []

  } catch (error) {
    console.error('Error fetching dashboard:', error)
  } finally {
    isLoading.value = false
  }
}

function formatCurrency(value: number) {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    minimumFractionDigits: 0
  }).format(value)
}

function formatDate(dateString: string) {
  return new Date(dateString).toLocaleDateString('id-ID', {
    day: 'numeric',
    month: 'short',
    year: 'numeric'
  })
}

function getStatusClass(status: string) {
  const classes: Record<string, string> = {
    draft: 'badge-gray',
    pending: 'badge-yellow',
    approved: 'badge-blue',
    partial: 'badge-purple',
    received: 'badge-green',
    cancelled: 'badge-red'
  }
  return classes[status] || 'badge-gray'
}
</script>

<template>
  <div class="dashboard">
    <!-- Loading -->
    <div v-if="isLoading" class="loading-state">
      <i class="pi pi-spin pi-spinner"></i>
      <span>Memuat data...</span>
    </div>

    <template v-else>
      <!-- Stats Cards -->
      <div class="stats-grid">
        <div class="stat-card">
          <div class="stat-icon icon-blue">
            <i class="pi pi-box"></i>
          </div>
          <div class="stat-content">
            <p class="stat-value">{{ stats.totalProducts }}</p>
            <p class="stat-label">Total Produk</p>
          </div>
        </div>

        <div class="stat-card">
          <div class="stat-icon icon-green">
            <i class="pi pi-database"></i>
          </div>
          <div class="stat-content">
            <p class="stat-value">{{ stats.totalStock.toLocaleString() }}</p>
            <p class="stat-label">Total Stock</p>
          </div>
        </div>

        <div class="stat-card">
          <div class="stat-icon icon-yellow">
            <i class="pi pi-shopping-cart"></i>
          </div>
          <div class="stat-content">
            <p class="stat-value">{{ stats.pendingPO }}</p>
            <p class="stat-label">PO Pending</p>
          </div>
        </div>

        <div class="stat-card">
          <div class="stat-icon icon-red">
            <i class="pi pi-chart-line"></i>
          </div>
          <div class="stat-content">
            <p class="stat-value">{{ stats.monthlySales.toLocaleString() }}</p>
            <p class="stat-label">Penjualan Bulan Ini</p>
          </div>
        </div>
      </div>

      <!-- Content Grid -->
      <div class="content-grid">
        <!-- Recent PO -->
        <div class="card">
          <div class="card-header">
            <h3>Purchase Order Terbaru</h3>
          </div>
          <div class="card-body">
            <table v-if="recentPO.length > 0" class="simple-table">
              <thead>
                <tr>
                  <th>No. PO</th>
                  <th>Cabang</th>
                  <th>Tanggal</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="po in recentPO" :key="po.id">
                  <td class="font-medium">{{ po.po_number }}</td>
                  <td>{{ po.branches?.nama }}</td>
                  <td>{{ formatDate(po.tanggal) }}</td>
                  <td>
                    <span class="badge" :class="getStatusClass(po.status)">
                      {{ po.status }}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
            <div v-else class="empty-state">
              <p>Belum ada data PO</p>
            </div>
          </div>
        </div>

        <!-- Top Products -->
        <div class="card">
          <div class="card-header">
            <h3>Produk Stock Tertinggi</h3>
          </div>
          <div class="card-body">
            <table v-if="topProducts.length > 0" class="simple-table">
              <thead>
                <tr>
                  <th>Kode</th>
                  <th>Nama</th>
                  <th>Stock</th>
                  <th>Harga</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="product in topProducts" :key="product.kode_barang">
                  <td class="font-medium">{{ product.kode_barang }}</td>
                  <td>{{ product.nama }}</td>
                  <td>{{ product.stock?.toLocaleString() }}</td>
                  <td>{{ formatCurrency(product.harga) }}</td>
                </tr>
              </tbody>
            </table>
            <div v-else class="empty-state">
              <p>Belum ada data produk</p>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>

<style scoped>
.dashboard {
  max-width: 1400px;
}

.loading-state {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  padding: 3rem;
  color: #6b7280;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  gap: 1.25rem;
  margin-bottom: 1.5rem;
}

.stat-card {
  background: white;
  border-radius: 12px;
  padding: 1.25rem;
  display: flex;
  align-items: center;
  gap: 1rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.stat-icon {
  width: 48px;
  height: 48px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.25rem;
}

.icon-blue { background: #dbeafe; color: #2563eb; }
.icon-green { background: #dcfce7; color: #16a34a; }
.icon-yellow { background: #fef3c7; color: #d97706; }
.icon-red { background: #fee2e2; color: #dc2626; }

.stat-content {
  flex: 1;
}

.stat-value {
  font-size: 1.5rem;
  font-weight: 700;
  color: #1f2937;
  line-height: 1;
}

.stat-label {
  font-size: 0.8125rem;
  color: #6b7280;
  margin-top: 0.25rem;
}

.content-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
  gap: 1.25rem;
}

.card {
  background: white;
  border-radius: 12px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  overflow: hidden;
}

.card-header {
  padding: 1rem 1.25rem;
  border-bottom: 1px solid #e5e7eb;
}

.card-header h3 {
  font-size: 0.9375rem;
  font-weight: 600;
  color: #1f2937;
}

.card-body {
  padding: 0;
}

.simple-table {
  width: 100%;
  border-collapse: collapse;
}

.simple-table th {
  padding: 0.75rem 1rem;
  text-align: left;
  font-size: 0.6875rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: #6b7280;
  background: #f9fafb;
  border-bottom: 1px solid #e5e7eb;
}

.simple-table td {
  padding: 0.75rem 1rem;
  font-size: 0.8125rem;
  border-bottom: 1px solid #e5e7eb;
}

.simple-table tr:last-child td {
  border-bottom: none;
}

.font-medium {
  font-weight: 500;
}

.badge {
  display: inline-block;
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
  font-size: 0.6875rem;
  font-weight: 600;
  text-transform: uppercase;
}

.badge-gray { background: #f3f4f6; color: #6b7280; }
.badge-yellow { background: #fef3c7; color: #92400e; }
.badge-blue { background: #dbeafe; color: #1e40af; }
.badge-purple { background: #ede9fe; color: #6d28d9; }
.badge-green { background: #dcfce7; color: #166534; }
.badge-red { background: #fee2e2; color: #991b1b; }

.empty-state {
  padding: 2rem;
  text-align: center;
  color: #9ca3af;
}
</style>
