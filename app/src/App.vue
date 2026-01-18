<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { RouterView, RouterLink, useRoute, useRouter } from 'vue-router'
import { useAuthStore } from './stores/authStore'
import { storeToRefs } from 'pinia'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const { isAuthenticated, isAdmin, userName, userInitials, isLoading } = storeToRefs(authStore)

const sidebarCollapsed = ref(false)
const userMenuOpen = ref(false)

// Navigation items with icons
const navItems = computed(() => {
  const items = [
    { path: '/', name: 'Dashboard', icon: 'pi-chart-bar' },
    { path: '/persediaan', name: 'Persediaan', icon: 'pi-box' },
    { path: '/pembelian', name: 'Pembelian', icon: 'pi-shopping-cart' },
    { path: '/penerimaan', name: 'Penerimaan Barang', icon: 'pi-download' },
    { path: '/penjualan', name: 'Penjualan', icon: 'pi-money-bill' },
    { path: '/sales-plan', name: 'Sales Plan', icon: 'pi-chart-line' },
    { path: '/laporan', name: 'Laporan', icon: 'pi-file' },
  ]
  
  // Add Users menu for admin only
  if (isAdmin.value) {
    items.push({ path: '/users', name: 'Users', icon: 'pi-users' })
  }
  
  return items
})

const isActiveRoute = (path: string) => {
  if (path === '/') return route.path === '/'
  return route.path.startsWith(path)
}

async function handleLogout() {
  await authStore.signOut()
  router.push('/login')
}

onMounted(async () => {
  await authStore.initialize()
})

const isLoginPage = computed(() => route.path === '/login')
</script>

<template>
  <!-- Login page without layout -->
  <template v-if="isLoginPage || isLoading">
    <div v-if="isLoading" class="loading-screen">
      <div class="loading-content">
        <div class="loading-logo">
          <img src="/logo.png" alt="JTM Logo" />
        </div>
        <div class="loading-text">
          <i class="pi pi-spin pi-spinner"></i>
          <span>Loading...</span>
        </div>
      </div>
    </div>
    <RouterView v-else />
  </template>

  <!-- Main Layout -->
  <template v-else>
    <div class="app-layout">
      <!-- Sidebar -->
      <aside 
        :class="sidebarCollapsed ? 'sidebar-collapsed' : 'sidebar-expanded'"
        class="app-sidebar"
      >
        <!-- Logo -->
        <div class="sidebar-header" :class="sidebarCollapsed ? 'justify-center' : ''">
          <div class="logo-wrapper">
            <img src="/logo.png" alt="JTM" class="logo-img" />
            <span v-if="!sidebarCollapsed" class="logo-text">JTM Order</span>
          </div>
        </div>

        <!-- Navigation -->
        <nav class="sidebar-nav">
          <div class="nav-items">
            <RouterLink
              v-for="item in navItems"
              :key="item.path"
              :to="item.path"
              :class="[
                isActiveRoute(item.path) 
                  ? 'nav-item-active' 
                  : 'nav-item',
                sidebarCollapsed ? 'justify-center' : ''
              ]"
              class="nav-link"
              :title="sidebarCollapsed ? item.name : ''"
            >
              <i :class="['pi', item.icon]"></i>
              <span v-if="!sidebarCollapsed">{{ item.name }}</span>
            </RouterLink>
          </div>
        </nav>

        <!-- Collapse Toggle -->
        <button
          @click="sidebarCollapsed = !sidebarCollapsed"
          class="collapse-btn"
        >
          <i :class="['pi', sidebarCollapsed ? 'pi-angle-double-right' : 'pi-angle-double-left']"></i>
        </button>

        <!-- User Section -->
        <div class="sidebar-user">
          <div 
            @click="userMenuOpen = !userMenuOpen"
            :class="sidebarCollapsed ? 'justify-center' : ''"
            class="user-trigger"
          >
            <div class="user-avatar">
              {{ userInitials }}
            </div>
            <div v-if="!sidebarCollapsed" class="user-info">
              <p class="user-name">{{ userName }}</p>
              <p class="user-role">{{ isAdmin ? 'Admin' : 'User' }}</p>
            </div>
          </div>

          <!-- Dropdown -->
          <div v-if="userMenuOpen && !sidebarCollapsed" class="user-menu">
            <button @click="handleLogout" class="menu-item-logout">
              <i class="pi pi-sign-out"></i>
              <span>Logout</span>
            </button>
          </div>
        </div>
      </aside>

      <!-- Main Content -->
      <main 
        :class="sidebarCollapsed ? 'main-collapsed' : 'main-expanded'"
        class="app-main"
      >
        <!-- Top Bar -->
        <header class="top-bar">
          <div class="top-bar-content">
            <h1 class="page-title">{{ route.name }}</h1>
            <div class="top-bar-actions">
              <button class="icon-btn">
                <i class="pi pi-bell"></i>
              </button>
            </div>
          </div>
        </header>

        <!-- Page Content -->
        <div class="page-content">
          <RouterView />
        </div>
      </main>
    </div>
  </template>
</template>

<style scoped>
.loading-screen {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #254060 0%, #1a2d42 100%);
}

.loading-content {
  text-align: center;
}

.loading-logo {
  width: 64px;
  height: 64px;
  margin: 0 auto 1rem;
  background: white;
  border-radius: 12px;
  padding: 8px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
}

.loading-logo img {
  width: 100%;
  height: 100%;
  object-fit: contain;
}

.loading-text {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  color: rgba(255, 255, 255, 0.8);
}

/* App Layout */
.app-layout {
  min-height: 100vh;
  display: flex;
}

/* Sidebar */
.app-sidebar {
  position: fixed;
  left: 0;
  top: 0;
  height: 100vh;
  background: #254060;
  transition: width 0.2s ease;
  z-index: 50;
  display: flex;
  flex-direction: column;
}

.sidebar-expanded {
  width: 15rem;
}

.sidebar-collapsed {
  width: 4rem;
}

.sidebar-header {
  height: 3.5rem;
  display: flex;
  align-items: center;
  padding: 0 1rem;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.logo-wrapper {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.logo-img {
  width: 32px;
  height: 32px;
  object-fit: contain;
  border-radius: 6px;
}

.logo-text {
  color: white;
  font-weight: 600;
  font-size: 0.9375rem;
}

/* Navigation */
.sidebar-nav {
  flex: 1;
  padding: 1rem 0;
  overflow-y: auto;
}

.nav-items {
  padding: 0 0.5rem;
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
}

.nav-link {
  display: flex;
  align-items: center;
  padding: 0.625rem 0.75rem;
  border-radius: 8px;
  color: rgba(255, 255, 255, 0.6);
  text-decoration: none;
  font-size: 0.8125rem;
  font-weight: 500;
  transition: all 0.15s ease;
  gap: 0.75rem;
}

.nav-link:hover {
  background: rgba(255, 255, 255, 0.1);
  color: white;
}

.nav-item-active {
  background: rgba(254, 0, 0, 0.15) !important;
  color: white !important;
  border-left: 3px solid #FE0000;
  margin-left: -3px;
}

.nav-link i {
  font-size: 1rem;
  width: 20px;
  text-align: center;
}

/* Collapse Button */
.collapse-btn {
  padding: 0.75rem;
  border: none;
  border-top: 1px solid rgba(255, 255, 255, 0.1);
  background: transparent;
  color: rgba(255, 255, 255, 0.5);
  cursor: pointer;
  transition: color 0.15s;
}

.collapse-btn:hover {
  color: white;
}

/* User Section */
.sidebar-user {
  border-top: 1px solid rgba(255, 255, 255, 0.1);
  padding: 0.75rem;
}

.user-trigger {
  display: flex;
  align-items: center;
  padding: 0.5rem;
  border-radius: 8px;
  cursor: pointer;
  transition: background 0.15s;
  gap: 0.75rem;
}

.user-trigger:hover {
  background: rgba(255, 255, 255, 0.1);
}

.user-avatar {
  width: 32px;
  height: 32px;
  background: linear-gradient(135deg, #FE0000, #cc0000);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-size: 0.75rem;
  font-weight: 600;
  flex-shrink: 0;
}

.user-info {
  overflow: hidden;
}

.user-name {
  color: white;
  font-size: 0.8125rem;
  font-weight: 500;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.user-role {
  color: rgba(255, 255, 255, 0.5);
  font-size: 0.6875rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.user-menu {
  margin-top: 0.5rem;
  background: rgba(0, 0, 0, 0.2);
  border-radius: 8px;
  overflow: hidden;
}

.menu-item-logout {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 0.625rem;
  padding: 0.625rem 1rem;
  border: none;
  background: transparent;
  color: #f87171;
  font-size: 0.8125rem;
  cursor: pointer;
  transition: background 0.15s;
}

.menu-item-logout:hover {
  background: rgba(255, 255, 255, 0.05);
}

/* Main Content */
.app-main {
  flex: 1;
  transition: margin-left 0.2s ease;
  display: flex;
  flex-direction: column;
}

.main-expanded {
  margin-left: 15rem;
}

.main-collapsed {
  margin-left: 4rem;
}

.top-bar {
  position: sticky;
  top: 0;
  z-index: 40;
  background: white;
  border-bottom: 1px solid #e5e7eb;
  height: 3.5rem;
}

.top-bar-content {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 100%;
  padding: 0 1.5rem;
}

.page-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: #1f2937;
}

.top-bar-actions {
  display: flex;
  gap: 0.5rem;
}

.icon-btn {
  width: 36px;
  height: 36px;
  border-radius: 8px;
  background: #f3f4f6;
  border: none;
  color: #6b7280;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.15s;
}

.icon-btn:hover {
  background: #e5e7eb;
  color: #374151;
}

.page-content {
  flex: 1;
  padding: 1.5rem;
  background: #f9fafb;
  min-height: calc(100vh - 3.5rem);
}

.justify-center {
  justify-content: center;
}
</style>
