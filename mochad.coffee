# Mochad plugin

module.exports = (env) ->

  # Require [convict](https://www.npmjs.org/package/convict) for config validation.
  convict = env.require "convict"

  # Require the [Q](https://www.npmjs.org/package/q) promise library
  Q = env.require 'q'

  # Require [lodash](https://www.npmjs.org/package/lodash)
  _ = env.require 'lodash'
  
  # Require [net](https://www.npmjs.org/package/net)
  net = env.require 'net'

  # ###Plugin class
  class MochadPlugin extends env.plugins.Plugin

    # ####init()
    #  
    # #####params:
    #  * `app` is the [express] instance the framework is using.
    #  * `framework` the framework itself
    #  * `config` the properties the user specified as config for your plugin in the `plugins` 
    #     section of the config.json file 
    # 
    init: (app, @framework, config) =>
      conf = convict require("./mochad-config-schema")
      conf.load(config)
      conf.validate()

    # ####createDevice()
    #  
    # #####params:
    #  * `deviceConfig` 
    # 
    createDevice: (deviceConfig) =>
      switch deviceConfig.class
        when "Mochad" 
          @framework.registerDevice(new Mochad(@framework, deviceConfig))
          return true
        else
          return false

  # Device schema
  deviceConfigSchema = require("./mochad-device-schema")
  # Unit schema
  unitConfigSchema   = require("./mochad-unit-schema")

  # #### Mochad class
  class Mochad extends env.devices.Sensor

    # ####constructor()
    #  
    # #####params:
    #  * `deviceConfig`
    # 
    constructor: (@framework, deviceConfig) ->
      conf = convict(_.cloneDeep(deviceConfigSchema))
      conf.load(deviceConfig)
      conf.validate()

      @id        = conf.get('id')
      @name      = conf.get('name')
      @host      = conf.get('host')
      @port      = conf.get('port')
      @house     = conf.get('house')
      @units     = conf.get('units')

      env.logger.debug("Initiated id='#{@id}', name='#{@name}', host='#{@host}', port='#{@port}', house='#{@house}'")

      for unitConfig in @units
        switch unitConfig.class
          when "MochadSwitch" 
            device = new MochadSwitch(@, @house, unitConfig)
            @framework.registerDevice(device)
            @units[device.unit] = device;

      @connection = @initConnection(@host, @port)
      @sendCommand("rftopl " + @house.toLowerCase()) # TODO RF commands are not received very well???
      @sendCommand("st");

      super()

    # ####initConnection()
    # 
    # TODO Recover self if connection is lost
    initConnection: (host, port)->
      connection = net.createConnection(port, host)

      connection.on 'connect', () ->
        env.logger.debug("Opened connection")
      
      connection.on 'data', ((data) ->
        lines = data.toString()
        #env.logger.debug(lines)

        # Handling "st" result
        #  example: 05/30 20:41:34 Device status
        #  example: 05/30 20:41:34 House P: 1=1,2=0,3=0,4=0,5=0,6=0,7=0,8=0,9=0,10=0,11=0,12=0,13=0,14=0,15=0,16=0
        if m = /^\d{2}\/\d{2}\s+(?:\d{2}:){2}\d{2}\s+Device status\n\d{2}\/\d{2}\s+(?:\d{2}:){2}\d{2}\s+House\s+([A-P]): ((?:\d{1,2}=[01],?)+)$/m.exec(lines)
          house = m[1]
          if house is not @house then return 
          for unit2status in m[2].split(",")
              n = unit2status.split("=")
              if unit = @units[n[0]] 
                state = if parseInt(n[1], 10) is 1 then true else false
                env.logger.debug("House #{@house} unit #{unit.unit} has state #{state}");
                unit._setState(state)

        # Handling all-units-on/off
        #  example: 05/22 00:34:04 Rx PL House: P Func: All units on
        #  example: 05/22 00:34:04 Rx PL House: P Func: All units off
        else if m = /^\d{2}\/\d{2}\s+(?:\d{2}:){2}\d{2}\s(Rx|Tx)\s+(RF|PL)\s+House:\s+([A-P])\s+Func:\s+All\s+units\s+(on|off)$/m.exec(lines)
          house = m[3]
          if house is not @house then return 
          rxtx  = if m[1] is "Rx" then "received" else "sent"
          rfpl  = if m[2] is "RF" then "RF" else "powerline"
          state = m[4]
          env.logger.debug("House #{@house} #{rxtx} #{rfpl} all #{state}")
          state = if state is "on" then true else false
          # TODO Throw this event
          for key, unit of @units
            unit._setState(state)

        # Handling simple on/off
        #  example: 05/30 20:59:20 Tx PL HouseUnit: P1
        #  example: 05/30 20:59:20 Tx PL House: P Func: On
        else if m = /^\d{2}\/\d{2}\s+(?:\d{2}:){2}\d{2}\s(?:Rx|Tx)\s+(?:RF|PL)\s+HouseUnit: [A-P](\d{1,2})\n\d{2}\/\d{2}\s+(?:\d{2}:){2}\d{2}\s(Rx|Tx)\s+(RF|PL)\s+House:\s+([A-P])\s+Func:\s+(On|Off)$/m.exec(lines)
          house = m[4]
          if house is not @house then return 
          code  = m[1]
          rxtx  = if m[2] is "Rx" then "received" else "sent"
          rfpl  = if m[3] is "RF" then "RF" else "powerline"
          state = m[5]
          env.logger.debug("House #{@house} unit #{code} #{rxtx} #{rfpl} #{state}")
          state = if state is "On" then true else false
          # TODO Throw this event
          if unit = @units[code]
            unit._setState(state)
      ).bind(@)

      connection.on 'end', (data) ->
        env.logger.debug("Connection closed")

      return connection

    # ####sendCommand()
    #  
    # #####params:
    #  * `connection`
    #  * `command`
    # 
    sendCommand: (command) ->
      @connection.write(command + "\r\n")

  # #### MochadSwitch class
  class MochadSwitch extends env.devices.SwitchActuator

    # ####constructor()
    #  
    # #####params:
    #  * `deviceConfig`
    # 
    constructor: (@Mochad, @house, unitConfig) ->
      conf = convict(_.cloneDeep(unitConfigSchema))
      env.logger.debug(unitConfig)
      conf.load(unitConfig)
      conf.validate()

      @id        = conf.get('id')
      @name      = conf.get('name')
      @unit      = conf.get('unit')

      env.logger.debug("Initiated for house='#{@house}': id='#{@id}', name='#{@name}', unit='#{@unit}'")

      super()

    # ####changeStateTo()
    #  
    # #####params:
    #  * `state`
    # 
    changeStateTo: (state) ->
      @Mochad.sendCommand("pl #{@house}#{@unit} " + ( if state then "on" else "off" ))

  # ###Wrap up 
  myMochadPlugin = new MochadPlugin
  return myMochadPlugin
