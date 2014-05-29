# Defines a `node-convict` config-schema and exports it.

module.exports =
  houseunit:
    doc: "The houseunit code"
    format: (val) -> (
      unless ((match = /^[A-P](\d{1,2})$/i.exec(val)) and (1 <= parseInt(match[1],10) <= 16)) then throw new Error('Not a valid houseunit')
      return
    )
    default: ""
  host:
    doc: "The hostname mochad is available on"
    format: "*"
    default: "localhost"
  port:
    doc: "The port mochad is available on"
    format: "port"
    default: 1099
