# Migration with device_index: 1
moved {
  from = aws_network_interface.additional[0]
  to   = aws_network_interface.multiple["1"]
}
