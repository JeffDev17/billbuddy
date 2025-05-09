module.exports = {
    content: [
        './app/helpers/**/*.rb',
        './app/javascript/**/*.js',
        './app/views/**/*.{erb,haml,html,slim}'
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
                    'success': '#10b981',
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