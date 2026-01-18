<script setup lang="ts">
import { computed } from 'vue'
import type { ActivityLog } from '../composables/useActivityLog'

const props = defineProps<{
  logs: ActivityLog[]
  isLoading: boolean
  title?: string
}>()

function formatDate(dateStr: string) {
  const date = new Date(dateStr)
  const now = new Date()
  const diffMs = now.getTime() - date.getTime()
  const diffMins = Math.floor(diffMs / 60000)
  const diffHours = Math.floor(diffMs / 3600000)
  const diffDays = Math.floor(diffMs / 86400000)

  if (diffMins < 1) return 'Baru saja'
  if (diffMins < 60) return `${diffMins} menit lalu`
  if (diffHours < 24) return `${diffHours} jam lalu`
  if (diffDays < 7) return `${diffDays} hari lalu`
  
  return date.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' })
}

function getActionIcon(action: string) {
  switch (action) {
    case 'create': return 'pi-plus-circle'
    case 'update': return 'pi-pencil'
    case 'delete': return 'pi-trash'
    case 'stock_in': return 'pi-arrow-down'
    case 'stock_out': return 'pi-arrow-up'
    case 'stock_adjust': return 'pi-sliders-h'
    default: return 'pi-circle'
  }
}

function getActionColor(action: string) {
  switch (action) {
    case 'create': return 'action-create'
    case 'update': return 'action-update'
    case 'delete': return 'action-delete'
    case 'stock_in': return 'action-stock-in'
    case 'stock_out': return 'action-stock-out'
    case 'stock_adjust': return 'action-adjust'
    default: return ''
  }
}
</script>

<template>
  <div class="activity-panel">
    <div class="panel-header">
      <h4>
        <i class="pi pi-history"></i>
        {{ title || 'Aktivitas Terbaru' }}
      </h4>
    </div>

    <div v-if="isLoading" class="panel-loading">
      <i class="pi pi-spin pi-spinner"></i>
    </div>

    <div v-else-if="logs.length === 0" class="panel-empty">
      <i class="pi pi-clock"></i>
      <p>Belum ada aktivitas</p>
    </div>

    <div v-else class="activity-list">
      <div 
        v-for="log in logs" 
        :key="log.id" 
        class="activity-item"
      >
        <div class="activity-icon" :class="getActionColor(log.action)">
          <i :class="['pi', getActionIcon(log.action)]"></i>
        </div>
        <div class="activity-content">
          <p class="activity-desc">{{ log.description }}</p>
          <div class="activity-meta">
            <span class="activity-user">{{ log.user_name || 'System' }}</span>
            <span class="activity-time">{{ formatDate(log.created_at) }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.activity-panel {
  background: white;
  border-radius: 12px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  overflow: hidden;
  height: fit-content;
  max-height: calc(100vh - 150px);
  display: flex;
  flex-direction: column;
}

.panel-header {
  padding: 1rem 1.25rem;
  border-bottom: 1px solid #e5e7eb;
  background: #f9fafb;
}

.panel-header h4 {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  font-weight: 600;
  color: #374151;
  margin: 0;
}

.panel-header i {
  color: #6b7280;
}

.panel-loading, .panel-empty {
  padding: 2rem;
  text-align: center;
  color: #9ca3af;
}

.panel-empty i {
  font-size: 1.5rem;
  margin-bottom: 0.5rem;
}

.panel-empty p {
  font-size: 0.8125rem;
  margin: 0;
}

.activity-list {
  flex: 1;
  overflow-y: auto;
  padding: 0.5rem 0;
}

.activity-item {
  display: flex;
  gap: 0.75rem;
  padding: 0.75rem 1.25rem;
  transition: background 0.15s;
}

.activity-item:hover {
  background: #f9fafb;
}

.activity-icon {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  background: #f3f4f6;
  color: #6b7280;
}

.activity-icon i {
  font-size: 0.75rem;
}

.action-create { background: #dcfce7; color: #16a34a; }
.action-update { background: #dbeafe; color: #2563eb; }
.action-delete { background: #fef2f2; color: #dc2626; }
.action-stock-in { background: #dcfce7; color: #16a34a; }
.action-stock-out { background: #fef2f2; color: #dc2626; }
.action-adjust { background: #fef3c7; color: #d97706; }

.activity-content {
  flex: 1;
  min-width: 0;
}

.activity-desc {
  font-size: 0.8125rem;
  color: #374151;
  margin: 0 0 0.25rem 0;
  line-height: 1.4;
}

.activity-meta {
  display: flex;
  gap: 0.5rem;
  font-size: 0.6875rem;
  color: #9ca3af;
}

.activity-user {
  font-weight: 500;
  color: #6b7280;
}

.activity-time::before {
  content: '•';
  margin-right: 0.5rem;
}
</style>
