/**
 * Supabase Client Configuration
 * 
 * This file initializes the Supabase client for use throughout the application.
 * Make sure to set the environment variables in your .env file:
 * - VITE_SUPABASE_URL
 * - VITE_SUPABASE_ANON_KEY
 */

import { createClient, SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '../types/database.types'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string

if (!supabaseUrl || !supabaseAnonKey) {
    console.error('Missing Supabase environment variables!')
    console.error('Please create a .env file with VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY')
}

export const supabase: SupabaseClient<Database> = createClient<Database>(
    supabaseUrl || '',
    supabaseAnonKey || '',
    {
        auth: {
            autoRefreshToken: true,
            persistSession: true,
            detectSessionInUrl: true
        }
    }
)

// Helper function to check connection
export async function checkConnection(): Promise<boolean> {
    try {
        const { error } = await supabase.from('master_regions').select('id').limit(1)
        return !error
    } catch {
        return false
    }
}

export default supabase
