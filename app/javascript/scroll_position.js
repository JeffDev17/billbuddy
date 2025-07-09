// Scroll position preservation for edit links
window.preserveScrollPosition = function() {
  const scrollY = window.scrollY || window.pageYOffset;
  sessionStorage.setItem('editReturnScrollY', scrollY);
}

window.restoreScrollPosition = function() {
  const scrollY = sessionStorage.getItem('editReturnScrollY');
  if (scrollY) {
    const targetY = parseInt(scrollY);
    
    // Try multiple restore attempts with different delays
    setTimeout(() => {
      window.scrollTo(0, targetY);
    }, 50);
    
    setTimeout(() => {
      window.scrollTo(0, targetY);
    }, 200);
    
    setTimeout(() => {
      window.scrollTo(0, targetY);
      sessionStorage.removeItem('editReturnScrollY');
    }, 500);
  }
}

// Function to check and restore scroll position
function checkAndRestoreScroll() {
  const urlParams = new URLSearchParams(window.location.search);
  if (urlParams.get('restore_scroll') === 'true') {
    window.restoreScrollPosition();
  }
}

// Multiple event listeners to ensure restoration works
document.addEventListener('DOMContentLoaded', checkAndRestoreScroll);
document.addEventListener('turbo:load', checkAndRestoreScroll);
window.addEventListener('load', checkAndRestoreScroll); 