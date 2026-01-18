import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/authStore'

const routes = [
    {
        path: '/login',
        name: 'Login',
        component: () => import('../views/LoginView.vue'),
        meta: { requiresAuth: false }
    },
    {
        path: '/',
        name: 'Dashboard',
        component: () => import('../views/DashboardView.vue'),
        meta: { requiresAuth: true }
    },
    {
        path: '/persediaan',
        name: 'Persediaan',
        component: () => import('../views/PersediaanView.vue'),
        meta: { requiresAuth: true }
    },
    {
        path: '/pembelian',
        name: 'Pembelian',
        component: () => import('../views/PembelianView.vue'),
        meta: { requiresAuth: true }
    },
    {
        path: '/pembelian/create',
        name: 'Buat PO',
        component: () => import('../views/PembelianFormView.vue'),
        meta: { requiresAuth: true }
    },
    {
        path: '/pembelian/:id/edit',
        name: 'Edit PO',
        component: () => import('../views/PembelianFormView.vue'),
        meta: { requiresAuth: true }
    },
    {
        path: '/persediaan/:id',
        name: 'Detail Produk',
        component: () => import('../views/PersediaanDetailView.vue'),
        meta: { requiresAuth: true }
    },
    {
        path: '/penerimaan',
        name: 'Penerimaan Barang',
        component: () => import('../views/PenerimaanView.vue'),
        meta: { requiresAuth: true }
    },
    {
        path: '/penjualan',
        name: 'Penjualan',
        component: () => import('../views/PenjualanView.vue'),
        meta: { requiresAuth: true }
    },
    {
        path: '/sales-plan',
        name: 'Sales Plan',
        component: () => import('../views/SalesPlanView.vue'),
        meta: { requiresAuth: true }
    },
    {
        path: '/laporan',
        name: 'Laporan',
        component: () => import('../views/LaporanView.vue'),
        meta: { requiresAuth: true }
    },
    {
        path: '/users',
        name: 'Users',
        component: () => import('../views/UsersView.vue'),
        meta: { requiresAuth: true, requiresAdmin: true }
    }
]

const router = createRouter({
    history: createWebHistory(),
    routes
})

// Navigation guard
router.beforeEach(async (to, _from, next) => {
    const authStore = useAuthStore()

    // Wait for auth initialization
    if (authStore.isLoading) {
        await new Promise(resolve => {
            const check = () => {
                if (!authStore.isLoading) {
                    resolve(true)
                } else {
                    setTimeout(check, 50)
                }
            }
            check()
        })
    }

    const requiresAuth = to.meta.requiresAuth !== false

    if (requiresAuth && !authStore.isAuthenticated) {
        next('/login')
    } else if (to.path === '/login' && authStore.isAuthenticated) {
        next('/')
    } else {
        next()
    }
})

export default router
