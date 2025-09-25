// app/javascript/appointment_modals.js
window.openCancellationModal = function(appointmentId) {
  fetch(`/appointments/${appointmentId}/cancellation_options`).then((response) => response.text()).then((html) => {
    const existingModal = document.getElementById("cancellation-modal");
    if (existingModal) {
      existingModal.remove();
    }
    document.body.insertAdjacentHTML("beforeend", html);
    document.getElementById("cancellation-modal").classList.remove("hidden");
  }).catch((error) => {
    console.error("Error loading cancellation options:", error);
    alert("Erro ao carregar op\xE7\xF5es de cancelamento");
  });
};
window.closeCancellationModal = function() {
  const modal = document.getElementById("cancellation-modal");
  if (modal) {
    modal.remove();
  }
};
window.closeModalAfterSubmit = function(formId) {
  const form = document.getElementById(formId);
  if (form) {
    form.addEventListener("submit", function() {
      setTimeout(() => {
        closeCancellationModal();
        const actionModal = document.getElementById("appointment-action-modal");
        if (actionModal) {
          actionModal.remove();
        }
      }, 100);
    });
  }
};
window.openRescheduleModal = function(appointmentId) {
  window.location.href = `/appointments/${appointmentId}/edit`;
};
document.addEventListener("DOMContentLoaded", function() {
  document.addEventListener("click", function(event) {
    const cancellationModal = document.getElementById("cancellation-modal");
    if (cancellationModal && event.target === cancellationModal) {
      closeCancellationModal();
    }
    const rescheduleModal = document.getElementById("reschedule-modal");
    if (rescheduleModal && event.target === rescheduleModal) {
      rescheduleModal.remove();
    }
  });
  document.addEventListener("keydown", function(event) {
    if (event.key === "Escape") {
      closeCancellationModal();
      const rescheduleModal = document.getElementById("reschedule-modal");
      if (rescheduleModal) {
        rescheduleModal.remove();
      }
    }
  });
});
//# sourceMappingURL=/assets/appointment_modals.js.map
