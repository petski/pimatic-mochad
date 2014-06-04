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
  units:
    doc: "Units that this mochad handles"
    format: Array
    default: []
