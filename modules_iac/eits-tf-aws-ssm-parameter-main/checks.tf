check "securestring_unused_warning" {
  assert {
    condition = !(var.type != "SecureString" &&
      anytrue([
        strcontains(lower(var.name), "passw"),
        strcontains(lower(var.name), "pwd"),
        strcontains(lower(var.name), "key"),
        strcontains(lower(var.name), "secret"),
        strcontains(lower(var.name), "cert"),
        strcontains(lower(var.name), "passphrase"),
        strcontains(lower(var.name), "token")
    ]))
    error_message = "It looks like you might have sensitive data in your paremeter, you probably want to use SecureString."
  }
}

check "description_warning" {
  assert {
    condition     = var.description != null
    error_message = "AWS Best Practice recommends providing a useful description."
  }
}