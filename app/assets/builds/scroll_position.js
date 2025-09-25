// app/javascript/scroll_position.js
window.preserveScrollPosition = function() {
  const scrollY = window.scrollY || window.pageYOffset;
  sessionStorage.setItem("editReturnScrollY", scrollY);
};
window.restoreScrollPosition = function() {
  const scrollY = sessionStorage.getItem("editReturnScrollY");
  if (scrollY) {
    const targetY = parseInt(scrollY);
    setTimeout(() => {
      window.scrollTo(0, targetY);
    }, 50);
    setTimeout(() => {
      window.scrollTo(0, targetY);
    }, 200);
    setTimeout(() => {
      window.scrollTo(0, targetY);
      sessionStorage.removeItem("editReturnScrollY");
    }, 500);
  }
};
function checkAndRestoreScroll() {
  const urlParams = new URLSearchParams(window.location.search);
  if (urlParams.get("restore_scroll") === "true") {
    window.restoreScrollPosition();
  }
}
document.addEventListener("DOMContentLoaded", checkAndRestoreScroll);
document.addEventListener("turbo:load", checkAndRestoreScroll);
window.addEventListener("load", checkAndRestoreScroll);
//# sourceMappingURL=/assets/scroll_position.js.map
