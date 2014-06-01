# Defines a `node-convict` config-schema and exports it.

module.exports =
  host:
    doc: "Hostname mochad is available on"
    format: "*"
    default: "localhost"
  port:
    doc: "Port mochad is available on"
    format: "port"
    default: 1099
  house:
    doc: "X10 house-code"
    format: (val) -> (
      unless (match = /^[A-P]$/i.exec(val)) then throw new Error('Not a valid X10 house-code')
      return
    )
    default: ""
  units:
    doc: "Units that this mochad handles"
    format: Array
    default: []
