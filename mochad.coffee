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

  # Require (internal lib) [matcher](https://github.com/pimatic/pimatic/blob/master/lib/matcher.coffee)
  M = env.matcher

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
          Q(@framework.registerDevice(new Mochad(@framework, deviceConfig)))
            # TODO .then(@framework.ruleManager.addPredicateProvider(new MochadPredicateProvider(@framework)))
            .then(@framework.ruleManager.addActionProvider(new MochadActionProvider(@framework)))
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
            @unitsContainer[unit.housecode] ||= {} 
            if @unitsContainer[unit.housecode][unit.unitcode]
              throw new Error "Unit #{unit.housecode}#{unit.unitcode} not unique in configuration"
            @framework.registerDevice(unit)
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
                housecode = n[1].toLowerCase()
                for code2status in n[2].split(",")
                  o = code2status.split("=")
                  unitcode = parseInt(o[0], 10)
                  if @unitsContainer[housecode] and unit = @unitsContainer[housecode][unitcode]
                    state = if parseInt(o[1], 10) is 1 then true else false
                    env.logger.debug("House #{housecode} unit #{unitcode} has state #{state}");
                    unit._setState(state)

          # Handling all-units-on/off
          #  example: 05/22 00:34:04 Rx PL House: P Func: All units on
          #  example: 05/22 00:34:04 Rx PL House: P Func: All units off
          else if m = /^\d{2}\/\d{2}\s+(?:\d{2}:){2}\d{2}\s(Rx|Tx)\s+(RF|PL)\s+House:\s+([A-P])\s+Func:\s+All\s+(units|lights)\s+(on|off)$/.exec(lines)
            env.logger.debug("House #{housecode} #{rxtx} #{rfpl} all #{targets} #{state}")
            event = {
              protocol:  m[2].toLowerCase(),
              direction: m[1].toLowerCase(),
              housecode: m[3].toLowerCase(),
              unitcode:  "*" + m[4],
              state:     (if m[5] is "On" then true else false) 
            }
            env.logger.debug("Event: " + JSON.stringify(event))
            @emit 'event', event
            if event.protocol is "pl" and event.direction is "tx" and @unitsContainer[event.housecode]
              for unitcode, unit of @unitsContainer[event.housecode]
                env.logger.debug("House #{event.housecode} unit #{unitcode} has state #{event.state}");
                unit._setState(event.state)

          # Handling simple on/off
          #  example: 05/30 20:59:20 Tx PL HouseUnit: P1
          #  example: 05/30 20:59:20 Tx PL House: P Func: On
          # TODO Crap, damn sometimes buffer only contains one line, so it won't match ....
          else if m = /^\d{2}\/\d{2}\s+(?:\d{2}:){2}\d{2}\s(?:Rx|Tx)\s+(?:RF|PL)\s+HouseUnit:\s+[A-P](\d{1,2})\n\d{2}\/\d{2}\s+(?:\d{2}:){2}\d{2}\s(Rx|Tx)\s+(RF|PL)\s+House:\s+([A-P])\s+Func:\s+(On|Off)$/m.exec(lines)
            event = {
              protocol:  m[3].toLowerCase(),
              direction: m[2].toLowerCase(),
              housecode: m[4].toLowerCase(),
              unitcode:  parseInt(m[1], 10),
              state:     (if m[5] is "On" then true else false) 
            }
            env.logger.debug("Event: " + JSON.stringify(event))
            @emit 'event', event
            if event.protocol is "pl" and event.direction is "tx" and @unitsContainer[event.housecode] and unit = @unitsContainer[event.housecode][event.unitcode]
              unit._setState(event.state)
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
    sendCommand: (command) ->
      Q
      .try((() ->
          if @connection is null then throw new Error("No connection!")
          env.logger.debug("Sending '#{command}'")
          @connection.write(command + "\r\n")
      ).bind(@))
      .catch((error) -> env.logger.error("Couldn't send command '#{command}': " + error))

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
      @housecode = conf.get('housecode').toLowerCase()
      @unitcode  = parseInt(conf.get('unitcode'), 10)

      env.logger.debug("Initiated unit with: housecode='#{@housecode}', unitcode='#{@unitcode}, id='#{@id}', name='#{@name}'")

      super()

    # ####changeStateTo()
    #  
    # #####params:
    #  * `state`
    # 
    changeStateTo: (state) ->
      @Mochad.sendCommand("pl #{@housecode}#{@unitcode} " + ( if state then "on" else "off" ))

  class MochadActionProvider extends env.actions.ActionProvider

    constructor: (@framework) ->
    parseAction: (input, context) =>

      mochadDevices = _(@framework.devices).values().filter( 
        (device) => device instanceof Mochad
      ).value()

      if mochadDevices.length is 0 then return

      device = null
      match = null
      commandTokens = null

      setCommand = (m, tokens) => commandTokens = tokens

      m = M(input, context)
        .match('tell ')
        .matchDevice(mochadDevices, (m, d) =>
          m.match(' to send ')
            .matchStringWithVars((m, ct) => 
              if device? and device.id isnt d.id
                context?.addError(""""#{input.trim()}" is ambiguous.""")
                return
              device = d
              commandTokens = ct
              match = m.getFullMatch()
            )
        )
      
      if match
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new MochadActionHandler(@framework, device, commandTokens)
        }
      else
        return null

  class MochadActionHandler extends env.actions.ActionHandler

    constructor: (@framework, @device, @commandTokens) ->
    executeAction: (simulate) =>
      @framework.variableManager.evaluateStringExpression(@commandTokens).then( (command) =>
        if simulate
          # just return a promise fulfilled with a description about what we would do.
          __("would send \"%s\"", command)
        else
          @device.sendCommand(command)
      )

  # ###Wrap up 
  myMochadPlugin = new MochadPlugin
  return myMochadPlugin
