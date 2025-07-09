# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers", preload: true

# Chartkick setup - using public directory (loaded dynamically when needed)
pin "chartkick", to: "/js/chartkick.js", preload: false
pin "chart.js", to: "/js/chart.umd.js", preload: false
pin "chartjs-adapter-date-fns", to: "/js/chartjs-adapter-date-fns.bundle.min.js", preload: false

# FullCalendar
pin "@fullcalendar/core", to: "https://cdn.skypack.dev/@fullcalendar/core@6.1.15"
pin "@fullcalendar/daygrid", to: "https://cdn.skypack.dev/@fullcalendar/daygrid@6.1.15"
pin "@fullcalendar/timegrid", to: "https://cdn.skypack.dev/@fullcalendar/timegrid@6.1.15"
pin "@fullcalendar/interaction", to: "https://cdn.skypack.dev/@fullcalendar/interaction@6.1.15"
pin "@fullcalendar/list", to: "https://cdn.skypack.dev/@fullcalendar/list@6.1.15"
