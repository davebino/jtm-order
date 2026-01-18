<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/authStore'
import { storeToRefs } from 'pinia'

const router = useRouter()
const authStore = useAuthStore()
const { isLoading, error } = storeToRefs(authStore)

const mode = ref<'login' | 'register'>('login')
const email = ref('')
const password = ref('')
const name = ref('')
const successMessage = ref('')

async function handleLogin() {
  const success = await authStore.signInWithEmail(email.value, password.value)
  if (success) {
    router.push('/')
  }
}

async function handleRegister() {
  successMessage.value = ''
  const result = await authStore.signUp(email.value, password.value, name.value)
  if (result.success) {
    if (result.needsConfirmation) {
      successMessage.value = 'Registrasi berhasil! Silakan cek email untuk konfirmasi.'
      mode.value = 'login'
    } else {
      router.push('/')
    }
  }
}

function handleSubmit() {
  if (mode.value === 'login') {
    handleLogin()
  } else {
    handleRegister()
  }
}

function toggleMode() {
  mode.value = mode.value === 'login' ? 'register' : 'login'
  authStore.error = null
  successMessage.value = ''
}
</script>

<template>
  <div class="login-container">
    <!-- Login Card -->
    <div class="login-wrapper">
      <!-- Logo -->
      <div class="login-logo">
        <div class="logo-icon">
          <img src="/logo.png" alt="JTM Logo" />
        </div>
        <h1>JTM Order</h1>
        <p>Sales Order Management System</p>
      </div>

      <!-- Card -->
      <div class="login-card">
        <!-- Header -->
        <div class="login-header">
          <h2>{{ mode === 'login' ? 'Login' : 'Daftar Akun' }}</h2>
          <p>{{ mode === 'login' ? 'Masuk ke akun Anda' : 'Buat akun admin baru' }}</p>
        </div>

        <!-- Form -->
        <form @submit.prevent="handleSubmit" class="login-form">
          <!-- Name (Register only) -->
          <div v-if="mode === 'register'" class="form-group">
            <label>Nama Lengkap</label>
            <input
              v-model="name"
              type="text"
              required
              placeholder="John Doe"
              class="form-input"
            />
          </div>

          <!-- Email -->
          <div class="form-group">
            <label>Email Address</label>
            <input
              v-model="email"
              type="email"
              required
              placeholder="email@example.com"
              class="form-input"
            />
          </div>

          <!-- Password -->
          <div class="form-group">
            <label>Password</label>
            <input
              v-model="password"
              type="password"
              required
              :minlength="mode === 'register' ? 6 : undefined"
              placeholder="••••••••"
              class="form-input"
            />
            <small v-if="mode === 'register'" class="form-hint">Minimal 6 karakter</small>
          </div>

          <!-- Success Message -->
          <div v-if="successMessage" class="success-message">
            <p>
              <i class="pi pi-check-circle"></i>
              {{ successMessage }}
            </p>
          </div>

          <!-- Error Message -->
          <div v-if="error" class="error-message">
            <p>
              <i class="pi pi-exclamation-circle"></i>
              {{ error }}
            </p>
          </div>

          <!-- Submit Button -->
          <button
            type="submit"
            :disabled="isLoading"
            class="submit-btn"
          >
            <i v-if="isLoading" class="pi pi-spin pi-spinner"></i>
            {{ mode === 'login' ? 'Login' : 'Daftar' }}
          </button>
        </form>

        <!-- Toggle Mode -->
        <div class="toggle-mode">
          <span v-if="mode === 'login'">
            Belum punya akun? 
            <a href="#" @click.prevent="toggleMode">Daftar sekarang</a>
          </span>
          <span v-else>
            Sudah punya akun? 
            <a href="#" @click.prevent="toggleMode">Login</a>
          </span>
        </div>
      </div>

      <!-- Footer -->
      <p class="login-footer">
        © 2026 JTM Order
      </p>
    </div>
  </div>
</template>

<style scoped>
.login-container {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #1a2f4a 0%, #254060 50%, #3a5a80 100%);
  padding: 1rem;
}

.login-wrapper {
  width: 100%;
  max-width: 400px;
}

.login-logo {
  text-align: center;
  margin-bottom: 2rem;
}

.logo-icon {
  width: 64px;
  height: 64px;
  margin: 0 auto 1rem;
  background: white;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.2);
}

.logo-icon img {
  width: 48px;
  height: 48px;
  object-fit: contain;
}

.login-logo h1 {
  font-size: 1.75rem;
  font-weight: 700;
  color: white;
  margin-bottom: 0.25rem;
}

.login-logo p {
  font-size: 0.875rem;
  color: rgba(255, 255, 255, 0.7);
}

.login-card {
  background: white;
  border-radius: 16px;
  padding: 2rem;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
}

.login-header {
  text-align: center;
  margin-bottom: 1.5rem;
}

.login-header h2 {
  font-size: 1.5rem;
  font-weight: 700;
  color: #1f2937;
  margin-bottom: 0.25rem;
}

.login-header p {
  font-size: 0.875rem;
  color: #6b7280;
}

.login-form {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
}

.form-group label {
  font-size: 0.8125rem;
  font-weight: 500;
  color: #374151;
}

.form-input {
  padding: 0.75rem 1rem;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  font-size: 0.9375rem;
  transition: border-color 0.2s, box-shadow 0.2s;
}

.form-input:focus {
  outline: none;
  border-color: #254060;
  box-shadow: 0 0 0 3px rgba(37, 64, 96, 0.1);
}

.form-hint {
  font-size: 0.75rem;
  color: #9ca3af;
}

.error-message {
  padding: 0.75rem;
  background: #fef2f2;
  border: 1px solid #fecaca;
  border-radius: 8px;
}

.error-message p {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.8125rem;
  color: #dc2626;
  margin: 0;
}

.success-message {
  padding: 0.75rem;
  background: #f0fdf4;
  border: 1px solid #86efac;
  border-radius: 8px;
}

.success-message p {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.8125rem;
  color: #16a34a;
  margin: 0;
}

.submit-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.875rem;
  background: linear-gradient(135deg, #FE0000, #cc0000);
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  margin-top: 0.5rem;
}

.submit-btn:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(254, 0, 0, 0.3);
}

.submit-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.toggle-mode {
  text-align: center;
  margin-top: 1.5rem;
  font-size: 0.875rem;
  color: #6b7280;
}

.toggle-mode a {
  color: #254060;
  font-weight: 600;
  text-decoration: none;
}

.toggle-mode a:hover {
  text-decoration: underline;
}

.login-footer {
  text-align: center;
  margin-top: 1.5rem;
  font-size: 0.75rem;
  color: rgba(255, 255, 255, 0.5);
}
</style>
