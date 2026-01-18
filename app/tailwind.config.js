/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{vue,js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        // Yuasa brand colors
        'yuasa': {
          primary: '#1e3a5f',      // Dark blue
          secondary: '#e31937',    // Red
          accent: '#f7941d',       // Orange
          light: '#f5f7fa',        // Light gray
          dark: '#1a1a2e',         // Dark navy
        }
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      }
    },
  },
  plugins: [],
}
