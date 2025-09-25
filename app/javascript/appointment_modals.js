// Global functions for appointment modals

window.openCancellationModal = function(appointmentId) {
  fetch(`/appointments/${appointmentId}/cancellation_options`)
    .then(response => response.text())
    .then(html => {
      // Remove any existing modal
      const existingModal = document.getElementById('cancellation-modal');
      if (existingModal) {
        existingModal.remove();
      }
      
      document.body.insertAdjacentHTML('beforeend', html);
      document.getElementById('cancellation-modal').classList.remove('hidden');
    })
    .catch(error => {
      console.error('Error loading cancellation options:', error);
      alert('Erro ao carregar opções de cancelamento');
    });
}

window.closeCancellationModal = function() {
  const modal = document.getElementById('cancellation-modal');
  if (modal) {
    modal.remove();
  }
}

// Function to close modal after form submission
window.closeModalAfterSubmit = function(formId) {
  const form = document.getElementById(formId);
  if (form) {
    form.addEventListener('submit', function() {
      setTimeout(() => {
        closeCancellationModal();
        const actionModal = document.getElementById('appointment-action-modal');
        if (actionModal) {
          actionModal.remove();
        }
      }, 100);
    });
  }
}

window.openRescheduleModal = function(appointmentId) {
  // For now, redirect to edit page - can be enhanced later with modal
  window.location.href = `/appointments/${appointmentId}/edit`;
}

// Event listeners for modal interactions
document.addEventListener('DOMContentLoaded', function() {
  // Close modals when clicking outside
  document.addEventListener('click', function(event) {
    const cancellationModal = document.getElementById('cancellation-modal');
    if (cancellationModal && event.target === cancellationModal) {
      closeCancellationModal();
    }
    
    const rescheduleModal = document.getElementById('reschedule-modal');
    if (rescheduleModal && event.target === rescheduleModal) {
      rescheduleModal.remove();
    }
  });
  
  // Close modals with ESC key
  document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
      closeCancellationModal();
      const rescheduleModal = document.getElementById('reschedule-modal');
      if (rescheduleModal) {
        rescheduleModal.remove();
      }
    }
  });
});
