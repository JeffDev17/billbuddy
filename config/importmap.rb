# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers", preload: true

# Additional JS files - fix asset paths
pin "scroll_position", preload: true
pin "appointment_modals", preload: true

# Chartkick setup - using public directory (loaded dynamically when needed)
pin "chartkick", to: "/js/chartkick.js", preload: false
pin "chart.js", to: "/js/chart.umd.js", preload: false
pin "chartjs-adapter-date-fns", to: "/js/chartjs-adapter-date-fns.bundle.min.js", preload: false

# FullCalendar - removed importmap, using global window object instead
# Force restart to clear connection pool cache
