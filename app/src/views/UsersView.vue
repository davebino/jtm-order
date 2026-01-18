<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useUserStore, type UserProfile, type CreateUserData } from '../stores/userStore'
import { useAuthStore } from '../stores/authStore'
import { storeToRefs } from 'pinia'

const userStore = useUserStore()
const authStore = useAuthStore()
const { users, isLoading, error } = storeToRefs(userStore)
const { isAdmin, userProfile } = storeToRefs(authStore)

// Modal state
const showModal = ref(false)
const modalMode = ref<'add' | 'edit'>('add')
const editingUser = ref<UserProfile | null>(null)

// Form state
const form = ref<CreateUserData>({
  email: '',
  password: '',
  name: '',
  role: 'user'
})
const formError = ref('')
const isSaving = ref(false)

// Delete confirmation
const showDeleteConfirm = ref(false)
const userToDelete = ref<UserProfile | null>(null)

onMounted(() => {
  userStore.fetchUsers()
})

function openAddModal() {
  modalMode.value = 'add'
  form.value = { email: '', password: '', name: '', role: 'user' }
  formError.value = ''
  showModal.value = true
}

function openEditModal(user: UserProfile) {
  modalMode.value = 'edit'
  editingUser.value = user
  form.value = {
    email: user.email,
    password: '',
    name: user.name || '',
    role: user.role
  }
  formError.value = ''
  showModal.value = true
}

function closeModal() {
  showModal.value = false
  editingUser.value = null
}

async function handleSubmit() {
  formError.value = ''
  isSaving.value = true

  try {
    if (modalMode.value === 'add') {
      if (!form.value.email || !form.value.password) {
        formError.value = 'Email dan password wajib diisi'
        return
      }
      const success = await userStore.createUser(form.value)
      if (!success) {
        formError.value = userStore.error || 'Gagal membuat user'
        return
      }
    } else if (editingUser.value) {
      const success = await userStore.updateUser(editingUser.value.id, {
        name: form.value.name,
        role: form.value.role
      })
      if (!success) {
        formError.value = userStore.error || 'Gagal update user'
        return
      }
    }
    closeModal()
  } finally {
    isSaving.value = false
  }
}

function confirmDelete(user: UserProfile) {
  userToDelete.value = user
  showDeleteConfirm.value = true
}

async function handleDelete() {
  if (!userToDelete.value) return
  
  const success = await userStore.deleteUser(userToDelete.value.id)
  if (success) {
    showDeleteConfirm.value = false
    userToDelete.value = null
  }
}

async function toggleUserStatus(user: UserProfile) {
  await userStore.updateUser(user.id, { is_active: !user.is_active })
}

const canDeleteUser = (user: UserProfile) => {
  // Can't delete yourself
  return user.id !== userProfile.value?.id
}

function formatDate(dateString: string) {
  return new Date(dateString).toLocaleDateString('id-ID', {
    day: 'numeric',
    month: 'short',
    year: 'numeric'
  })
}
</script>

<template>
  <div class="users-view">
    <!-- Header -->
    <div class="view-header">
      <div>
        <h2>Manajemen User</h2>
        <p>Kelola akun pengguna aplikasi</p>
      </div>
      <button v-if="isAdmin" @click="openAddModal" class="btn-primary">
        <i class="pi pi-plus"></i>
        Tambah User
      </button>
    </div>

    <!-- Error Alert -->
    <div v-if="error" class="error-alert">
      <i class="pi pi-exclamation-circle"></i>
      {{ error }}
    </div>

    <!-- Loading -->
    <div v-if="isLoading" class="loading-state">
      <i class="pi pi-spin pi-spinner"></i>
      <span>Memuat data...</span>
    </div>

    <!-- Users Table -->
    <div v-else class="table-card">
      <table class="users-table">
        <thead>
          <tr>
            <th>Nama</th>
            <th>Email</th>
            <th>Role</th>
            <th>Status</th>
            <th>Tanggal Dibuat</th>
            <th v-if="isAdmin">Aksi</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="user in users" :key="user.id" :class="{ 'inactive-row': !user.is_active }">
            <td>
              <div class="user-cell">
                <div class="user-avatar" :class="user.role === 'admin' ? 'avatar-admin' : 'avatar-user'">
                  {{ (user.name || user.email).substring(0, 2).toUpperCase() }}
                </div>
                <span class="user-name">{{ user.name || '-' }}</span>
              </div>
            </td>
            <td>{{ user.email }}</td>
            <td>
              <span class="role-badge" :class="user.role === 'admin' ? 'badge-admin' : 'badge-user'">
                {{ user.role === 'admin' ? 'Admin' : 'User' }}
              </span>
            </td>
            <td>
              <span class="status-badge" :class="user.is_active ? 'badge-active' : 'badge-inactive'">
                {{ user.is_active ? 'Aktif' : 'Nonaktif' }}
              </span>
            </td>
            <td>{{ formatDate(user.created_at) }}</td>
            <td v-if="isAdmin">
              <div class="action-buttons">
                <button @click="openEditModal(user)" class="btn-icon" title="Edit">
                  <i class="pi pi-pencil"></i>
                </button>
                <button @click="toggleUserStatus(user)" class="btn-icon" :title="user.is_active ? 'Nonaktifkan' : 'Aktifkan'">
                  <i :class="user.is_active ? 'pi pi-ban' : 'pi pi-check'"></i>
                </button>
                <button 
                  v-if="canDeleteUser(user)"
                  @click="confirmDelete(user)" 
                  class="btn-icon btn-danger" 
                  title="Hapus"
                >
                  <i class="pi pi-trash"></i>
                </button>
              </div>
            </td>
          </tr>
          <tr v-if="users.length === 0">
            <td :colspan="isAdmin ? 6 : 5" class="empty-state">
              <i class="pi pi-users"></i>
              <p>Belum ada user</p>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Add/Edit Modal -->
    <div v-if="showModal" class="modal-overlay" @click.self="closeModal">
      <div class="modal-content">
        <div class="modal-header">
          <h3>{{ modalMode === 'add' ? 'Tambah User' : 'Edit User' }}</h3>
          <button @click="closeModal" class="btn-close">
            <i class="pi pi-times"></i>
          </button>
        </div>

        <form @submit.prevent="handleSubmit" class="modal-form">
          <div class="form-group">
            <label>Nama</label>
            <input 
              v-model="form.name" 
              type="text" 
              placeholder="Nama lengkap"
              class="form-input"
            />
          </div>

          <div class="form-group">
            <label>Email <span class="required">*</span></label>
            <input 
              v-model="form.email" 
              type="email" 
              placeholder="email@example.com"
              class="form-input"
              :disabled="modalMode === 'edit'"
            />
          </div>

          <div v-if="modalMode === 'add'" class="form-group">
            <label>Password <span class="required">*</span></label>
            <input 
              v-model="form.password" 
              type="password" 
              placeholder="Minimal 6 karakter"
              class="form-input"
            />
          </div>

          <div class="form-group">
            <label>Role</label>
            <select v-model="form.role" class="form-input">
              <option value="user">User</option>
              <option value="admin">Admin</option>
            </select>
          </div>

          <div v-if="formError" class="form-error">
            <i class="pi pi-exclamation-circle"></i>
            {{ formError }}
          </div>

          <div class="modal-actions">
            <button type="button" @click="closeModal" class="btn-secondary">
              Batal
            </button>
            <button type="submit" class="btn-primary" :disabled="isSaving">
              <i v-if="isSaving" class="pi pi-spin pi-spinner"></i>
              {{ modalMode === 'add' ? 'Tambah' : 'Simpan' }}
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- Delete Confirmation Modal -->
    <div v-if="showDeleteConfirm" class="modal-overlay" @click.self="showDeleteConfirm = false">
      <div class="modal-content modal-small">
        <div class="modal-header">
          <h3>Konfirmasi Hapus</h3>
        </div>
        <div class="modal-body">
          <p>Apakah Anda yakin ingin menghapus user <strong>{{ userToDelete?.email }}</strong>?</p>
          <p class="text-muted">Tindakan ini tidak dapat dibatalkan.</p>
        </div>
        <div class="modal-actions">
          <button @click="showDeleteConfirm = false" class="btn-secondary">
            Batal
          </button>
          <button @click="handleDelete" class="btn-danger">
            <i class="pi pi-trash"></i>
            Hapus
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.users-view {
  max-width: 1200px;
}

.view-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.5rem;
}

.view-header h2 {
  font-size: 1.5rem;
  font-weight: 700;
  color: #1f2937;
  margin-bottom: 0.25rem;
}

.view-header p {
  color: #6b7280;
  font-size: 0.875rem;
}

.btn-primary {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1.25rem;
  background: linear-gradient(135deg, #FE0000 0%, #cc0000 100%);
  color: white;
  border: none;
  border-radius: 8px;
  font-weight: 600;
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-primary:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(254, 0, 0, 0.3);
}

.btn-primary:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.btn-secondary {
  padding: 0.75rem 1.25rem;
  background: #f3f4f6;
  color: #374151;
  border: none;
  border-radius: 8px;
  font-weight: 600;
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-secondary:hover {
  background: #e5e7eb;
}

.btn-danger {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1.25rem;
  background: #dc2626;
  color: white;
  border: none;
  border-radius: 8px;
  font-weight: 600;
  font-size: 0.875rem;
  cursor: pointer;
}

.btn-danger:hover {
  background: #b91c1c;
}

.error-alert {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 1rem;
  background: #fef2f2;
  border: 1px solid #fecaca;
  border-radius: 8px;
  color: #dc2626;
  margin-bottom: 1rem;
}

.loading-state {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  padding: 3rem;
  color: #6b7280;
}

.table-card {
  background: white;
  border-radius: 12px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  overflow: hidden;
}

.users-table {
  width: 100%;
  border-collapse: collapse;
}

.users-table th {
  padding: 1rem;
  text-align: left;
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: #6b7280;
  background: #f9fafb;
  border-bottom: 1px solid #e5e7eb;
}

.users-table td {
  padding: 1rem;
  border-bottom: 1px solid #e5e7eb;
  font-size: 0.875rem;
}

.users-table tr:last-child td {
  border-bottom: none;
}

.inactive-row {
  opacity: 0.6;
}

.user-cell {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.user-avatar {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.75rem;
  font-weight: 600;
  color: white;
}

.avatar-admin {
  background: linear-gradient(135deg, #254060, #1a2d42);
}

.avatar-user {
  background: linear-gradient(135deg, #3b82f6, #2563eb);
}

.user-name {
  font-weight: 500;
  color: #1f2937;
}

.role-badge, .status-badge {
  display: inline-block;
  padding: 0.25rem 0.75rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 600;
}

.badge-admin {
  background: #fef3c7;
  color: #92400e;
}

.badge-user {
  background: #dbeafe;
  color: #1e40af;
}

.badge-active {
  background: #dcfce7;
  color: #166534;
}

.badge-inactive {
  background: #f3f4f6;
  color: #6b7280;
}

.action-buttons {
  display: flex;
  gap: 0.5rem;
}

.btn-icon {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: none;
  border-radius: 6px;
  background: #f3f4f6;
  color: #6b7280;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-icon:hover {
  background: #e5e7eb;
  color: #374151;
}

.btn-icon.btn-danger {
  padding: 0;
  background: #fef2f2;
  color: #dc2626;
}

.btn-icon.btn-danger:hover {
  background: #fee2e2;
}

.empty-state {
  text-align: center;
  padding: 3rem !important;
  color: #9ca3af;
}

.empty-state i {
  font-size: 2rem;
  margin-bottom: 0.5rem;
}

/* Modal Styles */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 100;
  padding: 1rem;
}

.modal-content {
  background: white;
  border-radius: 12px;
  width: 100%;
  max-width: 480px;
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
}

.modal-small {
  max-width: 400px;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.25rem 1.5rem;
  border-bottom: 1px solid #e5e7eb;
}

.modal-header h3 {
  font-size: 1.125rem;
  font-weight: 600;
  color: #1f2937;
}

.btn-close {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: none;
  border-radius: 6px;
  background: transparent;
  color: #6b7280;
  cursor: pointer;
}

.btn-close:hover {
  background: #f3f4f6;
}

.modal-body {
  padding: 1.5rem;
}

.modal-body p {
  margin-bottom: 0.5rem;
}

.text-muted {
  color: #9ca3af;
  font-size: 0.875rem;
}

.modal-form {
  padding: 1.5rem;
}

.form-group {
  margin-bottom: 1.25rem;
}

.form-group label {
  display: block;
  font-size: 0.875rem;
  font-weight: 500;
  color: #374151;
  margin-bottom: 0.5rem;
}

.required {
  color: #dc2626;
}

.form-input {
  width: 100%;
  padding: 0.75rem 1rem;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  font-size: 0.875rem;
  transition: all 0.2s;
}

.form-input:focus {
  outline: none;
  border-color: #254060;
  box-shadow: 0 0 0 3px rgba(37, 64, 96, 0.1);
}

.form-input:disabled {
  background: #f9fafb;
  color: #6b7280;
}

.form-error {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem;
  background: #fef2f2;
  border-radius: 6px;
  color: #dc2626;
  font-size: 0.875rem;
  margin-bottom: 1rem;
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
  padding: 1rem 1.5rem;
  border-top: 1px solid #e5e7eb;
}
</style>
