# Defines a `node-convict` config-schema and exports it.

module.exports =
  houseunit:
    doc: "The houseunit code"
    format: (f) -> (if ((match = /^[A-P](\d{1,2})$/i.exec(f)) and (16 <= parseInt(match[1],10) <= 20)) then true else false) # TODO doesn't work
    default: ""
  host:
    doc: "The hostname mochad is available on"
    format: "*"
    default: "localhost"
  port:
    doc: "The port mochad is available on"
    format: "port"
    default: 1099
