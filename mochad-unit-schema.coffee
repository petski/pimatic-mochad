# Defines a `node-convict` config-schema and exports it.

module.exports =
  code:
    doc: "Code of the unit"
    format: (val) -> (
      unless (1 <= parseInt(val,10) <= 16) then throw new Error('Not a valid code:' + val)
      return
    )
    default: ""
