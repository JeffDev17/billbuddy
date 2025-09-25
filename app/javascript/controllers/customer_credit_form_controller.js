import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["creditType", "packageSection", "customSection"]

  connect() {
    // Initialize form state
    this.toggleCreditType()
  }

  toggleCreditType() {
    const selectedType = this.getSelectedCreditType()
    
    if (selectedType === "package") {
      this.showPackageSection()
      this.hideCustomSection()
    } else if (selectedType === "custom") {
      this.hidePackageSection()
      this.showCustomSection()
    }
  }

  getSelectedCreditType() {
    const selectedRadio = this.creditTypeTargets.find(radio => radio.checked)
    return selectedRadio ? selectedRadio.value : "package"
  }

  showPackageSection() {
    this.packageSectionTarget.classList.remove("hidden")
    this.enablePackageField()
  }

  hidePackageSection() {
    this.packageSectionTarget.classList.add("hidden")
    this.disablePackageField()
  }

  showCustomSection() {
    this.customSectionTarget.classList.remove("hidden")
    this.enableCustomField()
  }

  hideCustomSection() {
    this.customSectionTarget.classList.add("hidden")
    this.disableCustomField()
  }

  enablePackageField() {
    const packageSelect = this.packageSectionTarget.querySelector("select")
    if (packageSelect) {
      packageSelect.disabled = false
      packageSelect.required = true
    }
  }

  disablePackageField() {
    const packageSelect = this.packageSectionTarget.querySelector("select")
    if (packageSelect) {
      packageSelect.disabled = true
      packageSelect.required = false
      packageSelect.value = ""
    }
  }

  enableCustomField() {
    const hoursInput = this.customSectionTarget.querySelector("input[type='number']")
    if (hoursInput) {
      hoursInput.disabled = false
      hoursInput.required = true
    }
  }

  disableCustomField() {
    const hoursInput = this.customSectionTarget.querySelector("input[type='number']")
    if (hoursInput) {
      hoursInput.disabled = true
      hoursInput.required = false
      hoursInput.value = ""
    }
  }
} 