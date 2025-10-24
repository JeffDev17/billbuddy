// Inicialização do tema dark mode
// Este script roda antes de carregar a página para evitar flash

(function() {
  function updateThemeIcon() {
    const themeIcon = document.getElementById('theme-icon');
    if (themeIcon) {
      if (document.documentElement.classList.contains('dark')) {
        themeIcon.className = 'fas fa-sun';
      } else {
        themeIcon.className = 'fas fa-moon';
      }
    }
  }

  // Verificar preferência do usuário
  if (localStorage.theme === 'dark' ||
      (!('theme' in localStorage) &&
          window.matchMedia('(prefers-color-scheme: dark)').matches)) {
    document.documentElement.classList.add('dark');
  } else {
    document.documentElement.classList.remove('dark');
  }

  // Atualizar ícone quando o DOM estiver pronto
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', updateThemeIcon);
  } else {
    updateThemeIcon();
  }
})();

