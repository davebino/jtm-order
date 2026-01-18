/**
 * Auth Store (useAuthStore)
 * 
 * Pinia store for managing Supabase authentication.
 * Handles login, logout, session management, and user profile.
 */

import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '../lib/supabaseClient'
import type { User, Session } from '@supabase/supabase-js'

export interface UserProfile {
    id: string
    email: string
    name: string | null
    role: 'admin' | 'user'
    is_active: boolean
}

export const useAuthStore = defineStore('auth', () => {
    // State
    const user = ref<User | null>(null)
    const session = ref<Session | null>(null)
    const userProfile = ref<UserProfile | null>(null)
    const isLoading = ref(true)
    const error = ref<string | null>(null)

    // Getters
    const isAuthenticated = computed(() => !!user.value)
    const isAdmin = computed(() => userProfile.value?.role === 'admin')
    const userEmail = computed(() => user.value?.email || '')
    const userName = computed(() => userProfile.value?.name || userEmail.value.split('@')[0])
    const userInitials = computed(() => {
        const name = userProfile.value?.name || user.value?.email || ''
        if (userProfile.value?.name && name.length > 0) {
            const parts = name.split(' ')
            if (parts.length > 1 && parts[0] && parts[1]) {
                return (parts[0][0] + parts[1][0]).toUpperCase()
            }
            return name.substring(0, 2).toUpperCase()
        }
        return name.length > 0 ? name.substring(0, 2).toUpperCase() : 'U'
    })

    // Actions
    async function fetchUserProfile(userId: string) {
        try {
            const { data, error: fetchError } = await supabase
                .from('user_profiles')
                .select('*')
                .eq('id', userId)
                .single()

            if (fetchError) {
                console.error('Error fetching user profile:', fetchError)
                return null
            }

            userProfile.value = data
            return data
        } catch (err) {
            console.error('Error fetching profile:', err)
            return null
        }
    }

    async function initialize() {
        isLoading.value = true
        try {
            // Get current session
            const { data: { session: currentSession } } = await supabase.auth.getSession()
            session.value = currentSession
            user.value = currentSession?.user || null

            // Fetch user profile if authenticated
            if (currentSession?.user) {
                await fetchUserProfile(currentSession.user.id)
            }

            // Listen for auth changes
            supabase.auth.onAuthStateChange(async (_event, newSession) => {
                session.value = newSession
                user.value = newSession?.user || null

                if (newSession?.user) {
                    await fetchUserProfile(newSession.user.id)
                } else {
                    userProfile.value = null
                }
            })
        } catch (err) {
            console.error('Auth initialization error:', err)
        } finally {
            isLoading.value = false
        }
    }

    async function signInWithEmail(email: string, password: string) {
        isLoading.value = true
        error.value = null

        try {
            const { data, error: signInError } = await supabase.auth.signInWithPassword({
                email,
                password
            })

            if (signInError) throw signInError

            session.value = data.session
            user.value = data.user

            // Fetch user profile after login
            if (data.user) {
                await fetchUserProfile(data.user.id)
            }

            return true
        } catch (err: unknown) {
            error.value = err instanceof Error ? err.message : 'Login failed'
            return false
        } finally {
            isLoading.value = false
        }
    }

    async function signOut() {
        isLoading.value = true
        try {
            await supabase.auth.signOut()
            session.value = null
            user.value = null
            userProfile.value = null
        } catch (err) {
            console.error('Sign out error:', err)
        } finally {
            isLoading.value = false
        }
    }

    async function signUp(email: string, password: string, name: string) {
        isLoading.value = true
        error.value = null

        try {
            const { data, error: signUpError } = await supabase.auth.signUp({
                email,
                password,
                options: {
                    data: {
                        name,
                        role: 'admin' // First user is admin
                    }
                }
            })

            if (signUpError) throw signUpError

            // Auto login after signup
            if (data.user && data.session) {
                session.value = data.session
                user.value = data.user
                await fetchUserProfile(data.user.id)
            }

            return { success: true, needsConfirmation: !data.session }
        } catch (err: unknown) {
            error.value = err instanceof Error ? err.message : 'Registration failed'
            return { success: false, needsConfirmation: false }
        } finally {
            isLoading.value = false
        }
    }

    return {
        // State
        user,
        session,
        userProfile,
        isLoading,
        error,

        // Getters
        isAuthenticated,
        isAdmin,
        userEmail,
        userName,
        userInitials,

        // Actions
        initialize,
        fetchUserProfile,
        signInWithEmail,
        signUp,
        signOut
    }
})
