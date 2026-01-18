/**
 * Activity Log Composable
 * Provides functions to log and fetch activity logs
 */

import { ref } from 'vue'
import { supabase } from '../lib/supabaseClient'
import { useAuthStore } from '../stores/authStore'

export interface ActivityLog {
    id: string
    module: string
    action: string
    entity_id: string | null
    entity_name: string | null
    description: string
    user_name: string | null
    created_at: string
}

export function useActivityLog() {
    const authStore = useAuthStore()
    const logs = ref<ActivityLog[]>([])
    const isLoading = ref(false)

    async function logActivity(params: {
        module: string
        action: string
        entity_id?: string
        entity_name?: string
        description: string
        old_value?: Record<string, unknown>
        new_value?: Record<string, unknown>
        branch_id?: string
    }) {
        try {
            await supabase.from('activity_logs').insert([{
                module: params.module,
                action: params.action,
                entity_id: params.entity_id || null,
                entity_name: params.entity_name || null,
                description: params.description,
                old_value: params.old_value || null,
                new_value: params.new_value || null,
                user_id: authStore.user?.id || null,
                user_name: authStore.userName || null,
                branch_id: params.branch_id || null
            }])
        } catch (err) {
            console.error('Error logging activity:', err)
        }
    }

    async function fetchLogs(module: string, entityId?: string, limit = 20) {
        isLoading.value = true
        try {
            let query = supabase
                .from('activity_logs')
                .select('id, module, action, entity_id, entity_name, description, user_name, created_at')
                .eq('module', module)
                .order('created_at', { ascending: false })
                .limit(limit)

            if (entityId) {
                query = query.eq('entity_id', entityId)
            }

            const { data } = await query
            logs.value = data || []
        } catch (err) {
            console.error('Error fetching logs:', err)
        } finally {
            isLoading.value = false
        }
    }

    return {
        logs,
        isLoading,
        logActivity,
        fetchLogs
    }
}
