# Defines a `node-convict` config-schema and exports it.

module.exports =
  host:
    doc: "The hostname mochad is available on"
    format: "*"
    default: "localhost"
  port:
    doc: "The port mochad is available on"
    format: "port"
    default: 1099
  house:
    doc: "The house"
    format: (val) -> (
      unless (match = /^[A-P]$/i.exec(val)) then throw new Error('Not a valid house')
      return
    )
    default: ""
