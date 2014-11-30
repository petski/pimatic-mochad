module.exports = {
  title: "pimatic-mochad device config schemas"
  Mochad:
    title: "Mochad config options"
    type: "object"
    properties:
      id:
        description: "Unique id"
        type: "string"
        required: true
      class:
        description: "Class"
        type: "string"
        required: true
        pattern: "^Mochad$"
      name:
        description: "Unique name"
        type: "string"
        required: true
      host:
        description: "Hostname mochad is available on"
        type: "string"
        default: "localhost"
      port:
        description: "Port mochad is available on"
        type: "number"
        default: 1099
      units:
        description: "Units that this mochad handles"
        type: "array"
        default: []
        items:
          type: "object",
          properties:
            id:
              description: "Unique id"
              type: "string"
              required: true
            class:
              description: "Class"
              type: "string"
              required: true
              pattern: "^Mochad(Switch)$"
            name:
              description: "Unique name"
              type: "string"
              required: true
            housecode:
              description: "X10 housecode"
              type: "string"
              required: true
              pattern: "^[A-Pa-p]$"
            unitcode:
              description: "X10 unitcode"
              type: "number"
              required: true
              minimum: 1
              maximum: 16
            protocol:
              description: "X10 protocol (RF/PL)"
              type: "string"
              default: "pl"
              enum: ["rf", "pl"]
}
