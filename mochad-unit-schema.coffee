# Defines a `node-convict` config-schema and exports it.

module.exports =
  housecode:
    doc: "X10 housecode"
    format: (val) -> (
      unless (match = /^[A-P]$/i.exec(val)) then throw new Error('Not a valid X10 housecode: ' + val)
      return
    )
    default: ""
  unitcode:
    doc: "X10 unitcode"
    format: (val) -> (
      unless (1 <= parseInt(val,10) <= 16) then throw new Error('Not a valid X10 unitcode: ' + val)
      return
    )
    default: ""
