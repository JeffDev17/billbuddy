module.exports = {
    content: [
        './app/views/**/*.{erb,haml,html,slim}',
        './app/helpers/**/*.rb',
        './app/assets/stylesheets/**/*.css',
        './app/javascript/**/*.js'
    ],
    darkMode: 'class',
    theme: {
        extend: {
            colors: {
                'dark': {
                    'bg-primary': '#121212',
                    'bg-secondary': '#1e1e1e',
                    'bg-tertiary': '#2d2d2d',
                    'text-primary': '#e0e0e0',
                    'text-secondary': '#a0a0a0',
                    'accent': '#6366f1',
                    'accent-hover': '#4f46e5',
                    'success': '#059669',
                    'warning': '#f59e0b',
                    'danger': '#ef4444',
                }
            }
        },
    },
    plugins: [
        require('@tailwindcss/forms')
    ],
}