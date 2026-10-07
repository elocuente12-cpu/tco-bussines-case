check "description_warning" {
  assert {
    condition     = var.description != null
    error_message = "AWS Best Practice recommends providing a useful description."
  }
}