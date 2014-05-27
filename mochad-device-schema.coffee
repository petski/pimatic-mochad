# Defines a `node-convict` config-schema and exports it.

module.exports =
  houseunit:
    doc: "The houseunit code"
    format: (f) -> (match = /^[A-P](\d{1,2})$/i.exec(f)) and (1 <= match[1] <= 16) # TODO doesn't work
    default: ""
  host:
    doc: "The hostname mochad is available on"
    format: String,
    default: "localhost"
  port:
    doc: "The port mochad is available on"
    format: "port"
    default: 1099
