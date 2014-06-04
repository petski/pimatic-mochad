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

  # Require [reconnect-net](https://www.npmjs.org/package/reconnect-net)
  reconnect = require 'reconnect-net'

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
      dconf = convict(_.cloneDeep(deviceConfigSchema))
      dconf.load(deviceConfig)
      dconf.validate()

      @id        = dconf.get('id')
      @name      = dconf.get('name')
      @host      = dconf.get('host')
      @port      = dconf.get('port')
      @units     = dconf.get('units')

      env.logger.debug("Initiated id='#{@id}', name='#{@name}', host='#{@host}', port='#{@port}'")

      @unitsContainer = {}

      for unitConfig in @units
        uconf = convict(_.cloneDeep(unitConfigSchema))
        uconf.load(unitConfig)
        uconf.validate()
        switch uconf.get('class')
          when "MochadSwitch" 
            unit = new MochadSwitch(@, unitConfig)
            @framework.registerDevice(unit)
            @unitsContainer[unit.housecode] ||= {} 
            @unitsContainer[unit.housecode][unit.unitcode] = unit;
      
      @connection = null
      @initConnection(@host, @port)

      super()

    # ####initConnection()
    # 
    initConnection: (host, port)->

      # TODO Test 1) Start with non-working connection, make connection     work
      # TODO Test 2) Start with     working connection, make connection non-working and switch button in frontend
      reconnector = reconnect(((conn) ->

        # XXX Keep alive does not work [as expected](https://github.com/joyent/node/issues/6194)
        conn.setKeepAlive(true, 0)

        conn.setNoDelay(true)

        # TODO Improve mochads output (json?)
        conn.on 'data', ((data) ->
          lines = data.toString()

          #env.logger.debug(lines)

          # Handling "st" result
          # 06/04 21:50:55 Device status
          # 06/04 21:50:55 House A: 1=1
          # 06/04 21:50:55 House P: 1=1,2=0,3=1,4=0,5=1,6=0,7=0,8=0,9=0,10=0,11=0,12=0,13=0,14=0,15=0,16=0
          # 06/04 21:50:55 Security sensor status

          if m = /^\d{2}\/\d{2}\s+(?:\d{2}:){2}\d{2}\s+Device status\n((?:\d{2}\/\d{2}\s+(?:\d{2}:){2}\d{2}\s+House\s+[A-P]:\s+(?:\d{1,2}=[01],?)+\n)*)/m.exec(lines)
            for houseline in m[1].split("\n")
              if n = /^\d{2}\/\d{2}\s+(?:\d{2}:){2}\d{2}\s+House\s+([A-P]):\s+((?:\d{1,2}=[01],?)+)$/.exec(houseline)
                housecode = n[1]
                for code2status in n[2].split(",")
                  o = code2status.split("=")
                  unitcode = o[0]
                  if @unitsContainer[housecode] and unit = @unitsContainer[housecode][unitcode]
                    state = if parseInt(o[1], 10) is 1 then true else false
                    env.logger.debug("House #{housecode} unit #{unitcode} has state #{state}");
                    unit._setState(state)

          # Handling all-units-on/off
          #  example: 05/22 00:34:04 Rx PL House: P Func: All units on
          #  example: 05/22 00:34:04 Rx PL House: P Func: All units off
          else if m = /^\d{2}\/\d{2}\s+(?:\d{2}:){2}\d{2}\s(Rx|Tx)\s+(RF|PL)\s+House:\s+([A-P])\s+Func:\s+All\s+(units|lights)\s+(on|off)$/.exec(lines)
            rxtx      = if m[1] is "Rx" then "received" else "sent"
            rfpl      = if m[2] is "RF" then "RF" else "powerline"
            housecode = m[3]
            targets   = m[4]
            state     = if m[5] is "on" then true else false
            env.logger.debug("House #{housecode} #{rxtx} #{rfpl} all #{targets} #{state}")
            # TODO Throw this event
            if @unitsContainer[housecode]
              for unitcode, unit of @unitsContainer[housecode]
                env.logger.debug("House #{housecode} unit #{unitcode} has state #{state}");
                unit._setState(state)

          # Handling simple on/off
          #  example: 05/30 20:59:20 Tx PL HouseUnit: P1
          #  example: 05/30 20:59:20 Tx PL House: P Func: On
          else if m = /^\d{2}\/\d{2}\s+(?:\d{2}:){2}\d{2}\s(?:Rx|Tx)\s+(?:RF|PL)\s+HouseUnit:\s+[A-P](\d{1,2})\n\d{2}\/\d{2}\s+(?:\d{2}:){2}\d{2}\s(Rx|Tx)\s+(RF|PL)\s+House:\s+([A-P])\s+Func:\s+(On|Off)$/m.exec(lines)
            unitcode  = m[1]
            rxtx      = if m[2] is "Rx" then "received" else "sent"
            rfpl      = if m[3] is "RF" then "RF" else "powerline"
            housecode = m[4]
            state     = if m[5] is "On" then true else false
            env.logger.debug("House #{housecode} unit #{unitcode} #{rxtx} #{rfpl} #{state}")
            # TODO Throw this event
            if @unitsContainer[housecode] and unit = @unitsContainer[housecode][unitcode]
              env.logger.debug("House #{housecode} unit #{unitcode} has state #{state}");
              unit._setState(state)
        ).bind(@)
      ).bind(@)).connect(port, host);

      reconnector.on 'connect', ((connection) ->
        env.logger.info("(re)Opened connection")
        @connection = connection
        @sendCommand("st")
      ).bind(@)

      reconnector.on 'disconnect', ((err) -> 
        env.logger.error("Disconnected from #{@host}:#{@port}: " + err)
        @connection = null;
      ).bind(@)

    # ####sendCommand()
    #  
    # #####params:
    #  * `connection`
    #  * `command`
    # 
    # TODO returns a promise?
    sendCommand: (command) ->
      if not @connection 
        throw new Error("Received command '#{command}' while offline")
      @connection.write(command + "\r\n")

  # #### MochadSwitch class
  class MochadSwitch extends env.devices.SwitchActuator

    # ####constructor()
    #  
    # #####params:
    #  * `deviceConfig`
    # 
    constructor: (@Mochad, unitConfig) ->
      conf = convict(_.cloneDeep(unitConfigSchema))
      conf.load(unitConfig)
      conf.validate()

      @id        = conf.get('id')
      @name      = conf.get('name')
      @housecode = conf.get('housecode').toUpperCase()
      @unitcode  = conf.get('unitcode')

      env.logger.debug("Initiated unit with: housecode='#{@housecode}', unitcode='#{@unitcode}, id='#{@id}', name='#{@name}'")

      super()

    # ####changeStateTo()
    #  
    # #####params:
    #  * `state`
    # 
    changeStateTo: (state) ->
      @Mochad.sendCommand("pl #{@housecode}#{@unitcode} " + ( if state then "on" else "off" ))

  # ###Wrap up 
  myMochadPlugin = new MochadPlugin
  return myMochadPlugin
