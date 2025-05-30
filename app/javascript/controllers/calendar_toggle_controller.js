import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form"]

  toggle() {
    this.formTarget.classList.toggle('hidden');
  }

  hide() {
    this.formTarget.classList.add('hidden');
  }

  show() {
    this.formTarget.classList.remove('hidden');
  }
} 