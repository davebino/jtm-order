import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface CreateUserRequest {
    email: string
    password: string
    name: string
    role: 'admin' | 'user'
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // Get authorization token from request
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            throw new Error('No authorization header')
        }

        // Create Supabase client with user's token to verify they're admin
        const supabaseUrl = Deno.env.get('SUPABASE_URL')!
        const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

        // Verify the requesting user is an admin
        const supabaseUser = createClient(supabaseUrl, supabaseAnonKey, {
            global: { headers: { Authorization: authHeader } }
        })

        const { data: { user: requestingUser } } = await supabaseUser.auth.getUser()
        if (!requestingUser) {
            throw new Error('Not authenticated')
        }

        // Check if requesting user is admin
        const { data: profile } = await supabaseUser
            .from('user_profiles')
            .select('role')
            .eq('id', requestingUser.id)
            .single()

        if (!profile || profile.role !== 'admin') {
            throw new Error('Only admins can create users')
        }

        // Parse request body
        const { email, password, name, role }: CreateUserRequest = await req.json()

        if (!email || !password) {
            throw new Error('Email and password are required')
        }

        // Create admin client for user creation
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
            auth: { autoRefreshToken: false, persistSession: false }
        })

        // Create the new user
        const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
            email,
            password,
            email_confirm: true, // Auto-confirm email
            user_metadata: { name, role }
        })

        if (createError) {
            throw createError
        }

        return new Response(
            JSON.stringify({
                success: true,
                user: {
                    id: newUser.user.id,
                    email: newUser.user.email,
                    name,
                    role
                }
            }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error) {
        return new Response(
            JSON.stringify({ success: false, error: error.message }),
            {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
        )
    }
})
