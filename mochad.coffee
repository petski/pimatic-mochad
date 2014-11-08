# Mochad plugin

module.exports = (env) ->

  # Require the bluebird promise library
  Promise = env.require 'bluebird'

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

      deviceConfigSchema = require("./mochad-device-schema")
       
      @framework.deviceManager.registerDeviceClass("Mochad", {
        configDef: deviceConfigSchema.Mochad,
        createCallback: (config) => new Mochad(@framework, config)
      })

  # #### Mochad class
  class Mochad extends env.devices.Sensor

    # ####constructor()
    #  
    # #####params:
    #  * `deviceConfig`
    # 
    constructor: (@framework, @config) ->

      @id        = @config.id
      @name      = @config.name
      @host      = @config.host
      @port      = @config.port
      @units     = @config.units

      env.logger.debug("Initiating id='#{@id}', name='#{@name}', host='#{@host}', port='#{@port}'")

      @unitsContainer = {}

      for uconf in @units
        switch uconf.class
          when "MochadSwitch" 
            unit = new MochadSwitch(@, uconf)
            @unitsContainer[unit.housecode] ||= {} 
            if @unitsContainer[unit.housecode][unit.unitcode]
              throw new Error "Unit #{unit.housecode}#{unit.unitcode} not unique in configuration"
            @framework.deviceManager.registerDevice(unit)
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

          # env.logger.debug(lines)

          lastSeen = {} # TODO should be in 'this' to make it propertly work?

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
          # example2: 00:04:29.391 [pimatic-mochad] 09/02 00:04:29 Rx PL House: P Func: All units off
          # example2: 00:04:29.391 [pimatic-mochad]>
          else if m = /^\d{2}\/\d{2}\s+(?:\d{2}:){2}\d{2}\s(Rx|Tx)\s+(RF|PL)\s+House:\s+([A-P])\s+Func:\s+All\s+(units|lights)\s+(on|off)$/m.exec(lines)
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
          #  example2: 23:42:03.196 [pimatic-mochad] 09/01 23:42:03 Tx PL HouseUnit: P1
          #  example2: 23:42:03.196 [pimatic-mochad]>
          #  example2: 23:42:03.198 [pimatic-mochad] 09/01 23:42:03 Tx PL House: P Func: On
          else if m = /^\d{2}\/\d{2}\s+(?:\d{2}:){2}\d{2}\s(?:Rx|Tx)\s+(?:RF|PL)\s+HouseUnit:\s+([A-P])(\d{1,2})/m.exec(lines)
            lastSeen.housecode = m[1].toLowerCase()
            lastSeen.unitcode  = parseInt(m[2], 10)
            env.logger.debug("Event: " + JSON.stringify(lastSeen))

          if lastSeen.housecode and lastSeen.unitcode and m = /\d{2}\/\d{2}\s+(?:\d{2}:){2}\d{2}\s(Rx|Tx)\s+(RF|PL)\s+House:\s+([A-P])\s+Func:\s+(On|Off)$/m.exec(lines)
            event = {
              protocol:  m[2].toLowerCase(),
              direction: m[1].toLowerCase(),
              housecode: m[3].toLowerCase(),
              unitcode:  null, # filled later
              state:     (if m[4] is "On" then true else false) 
            }
            if event.housecode == lastSeen.housecode
              event.unitcode = lastSeen.unitcode
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
      Promise
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
    constructor: (@Mochad, uconf) ->
      @id        = uconf.id
      @name      = uconf.name
      @housecode = uconf.housecode.toLowerCase()
      @unitcode  = parseInt(uconf.unitcode, 10)

      env.logger.debug("Initiated unit with: housecode='#{@housecode}', unitcode='#{@unitcode}, id='#{@id}', name='#{@name}'")

      super()

    # ####changeStateTo()
    #  
    # #####params:
    #  * `state`
    # 
    changeStateTo: (state) ->
      @Mochad.sendCommand("pl #{@housecode}#{@unitcode} " + ( if state then "on" else "off" ))

  # TODO Needs to be implemented
  class MochadActionProvider extends env.actions.ActionProvider

    constructor: (@framework) ->
    parseAction: (input, context) =>

      mochadDevices = _(@framework.devices).values().filter( 
        (device) => device instanceof Mochad
      ).value()

      if mochadDevices.length is 0 then return

      match = null
      device = null
      commandTokens = null

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

  # TODO Needs to be implemented
  class MochadPredicateProvider extends env.predicates.PredicateProvider
  
    constructor: (@framework) ->
  
    parsePredicate: (input, context) ->

      mochadDevices = _(@framework.devices).values().filter( 
        (device) => device instanceof Mochad
      ).value()

      if mochadDevices.length is 0 then return

      match = null
      device = null
      direction = null
      commandTokens = null

      m = M(input, context)
        .matchDevice(mochadDevices, (m, d) =>
          m.match([' receives ', ' sends '], (m, s) ->
            m.matchStringWithVars((m, ct) => 
              if device? and device.id isnt d.id
                context?.addError(""""#{input.trim()}" is ambiguous.""")
                return
              device = d
              direction = if s is " receives" then "rx" else "tx"
              commandTokens = ct
              match = m.getFullMatch()
            )
          )
        )
      
      if match
        return {
          token: match
          nextInput: input.substring(match.length)
          predicateHandler: new MochadPredicateHandler(@framework, device, direction, commandTokens)
        }
      else
        return null

  class MochadPredicateHandler extends env.predicates.PredicateHandler

    constructor: (@framework, device, direction, commandTokens) ->

  # ###Wrap up 
  myMochadPlugin = new MochadPlugin
  return myMochadPlugin
