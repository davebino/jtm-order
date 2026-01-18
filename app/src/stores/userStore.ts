/**
 * User Store (useUserStore)
 * 
 * Pinia store for managing user CRUD operations.
 * Admin-only functionality for user management.
 */

import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../lib/supabaseClient'

export interface UserProfile {
    id: string
    email: string
    name: string | null
    role: 'admin' | 'user'
    is_active: boolean
    created_at: string
    updated_at: string
}

export interface CreateUserData {
    email: string
    password: string
    name: string
    role: 'admin' | 'user'
}

export const useUserStore = defineStore('user', () => {
    // State
    const users = ref<UserProfile[]>([])
    const isLoading = ref(false)
    const error = ref<string | null>(null)

    // Actions
    async function fetchUsers() {
        isLoading.value = true
        error.value = null

        try {
            const { data, error: fetchError } = await supabase
                .from('user_profiles')
                .select('*')
                .order('created_at', { ascending: false })

            if (fetchError) throw fetchError

            users.value = data || []
        } catch (err: unknown) {
            error.value = err instanceof Error ? err.message : 'Failed to fetch users'
            console.error('Error fetching users:', err)
        } finally {
            isLoading.value = false
        }
    }

    async function createUser(userData: CreateUserData): Promise<boolean> {
        isLoading.value = true
        error.value = null

        try {
            // Get current session for auth header
            const { data: { session } } = await supabase.auth.getSession()
            if (!session) throw new Error('Not authenticated')

            // Call Edge Function to create user
            const response = await fetch(
                `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/create-user`,
                {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${session.access_token}`
                    },
                    body: JSON.stringify(userData)
                }
            )

            const result = await response.json()

            if (!result.success) {
                throw new Error(result.error || 'Failed to create user')
            }

            // Refresh user list
            await fetchUsers()
            return true
        } catch (err: unknown) {
            error.value = err instanceof Error ? err.message : 'Failed to create user'
            console.error('Error creating user:', err)
            return false
        } finally {
            isLoading.value = false
        }
    }

    async function updateUser(userId: string, updates: Partial<UserProfile>): Promise<boolean> {
        isLoading.value = true
        error.value = null

        try {
            const { error: updateError } = await supabase
                .from('user_profiles')
                .update({
                    name: updates.name,
                    role: updates.role,
                    is_active: updates.is_active,
                    updated_at: new Date().toISOString()
                })
                .eq('id', userId)

            if (updateError) throw updateError

            // Update local state
            const index = users.value.findIndex(u => u.id === userId)
            if (index !== -1) {
                users.value[index] = { ...users.value[index], ...updates }
            }

            return true
        } catch (err: unknown) {
            error.value = err instanceof Error ? err.message : 'Failed to update user'
            console.error('Error updating user:', err)
            return false
        } finally {
            isLoading.value = false
        }
    }

    async function deleteUser(userId: string): Promise<boolean> {
        isLoading.value = true
        error.value = null

        try {
            const { error: deleteError } = await supabase
                .from('user_profiles')
                .delete()
                .eq('id', userId)

            if (deleteError) throw deleteError

            // Remove from local state
            users.value = users.value.filter(u => u.id !== userId)

            return true
        } catch (err: unknown) {
            error.value = err instanceof Error ? err.message : 'Failed to delete user'
            console.error('Error deleting user:', err)
            return false
        } finally {
            isLoading.value = false
        }
    }

    return {
        // State
        users,
        isLoading,
        error,

        // Actions
        fetchUsers,
        createUser,
        updateUser,
        deleteUser
    }
})
