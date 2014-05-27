# #mochad configuration options

# Declare your config option for your plugin here. 

# Defines a `node-convict` config-schema and exports it.
module.exports =
  host:
    doc: "Host on which mochad is running"
    format: String
    default: "localhost"
  host:
    doc: "Port on which mochad is running"
    format: "nat" # TODO 65535
    default: "1099"
