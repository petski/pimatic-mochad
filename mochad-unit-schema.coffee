# Defines a `node-convict` config-schema and exports it.

module.exports =
  unit:
    doc: "The unit"
    format: (val) -> (
      unless (1 <= parseInt(val,10) <= 16) then throw new Error('Not a valid unit:' + val)
      return
    )
    default: ""
