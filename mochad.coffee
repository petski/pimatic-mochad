# Mochad plugin

module.exports = (env) ->

  # Require [convict](https://www.npmjs.org/package/convict) for config validation.
  convict = env.require "convict"

  # Require the [Q](https://www.npmjs.org/package/q) promise library
  Q = env.require 'q'

  # Require the [cassert library](https://www.npmjs.org/package/cassert)
  assert = env.require 'cassert'

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
      @conf = convict require("./mochad-config-schema")
      @conf.load(config)
      @conf.validate()

    # ####createDevice()
    #  
    # #####params:
    #  * `deviceConfig` 
    # 
    createDevice: (deviceConfig) =>
      switch deviceConfig.class
        when "MochadSwitch" 
          @framework.registerDevice(new MochadSwitch deviceConfig)
          return true
        else
          return false

  # Device schema
  deviceConfigSchema = require("./mochad-device-schema")

  # #### Device class
  class MochadSwitch extends env.devices.SwitchActuator

    # ####constructor()
    #  
    # #####params:
    #  * `deviceConfig`
    # 
    constructor: (deviceConfig) ->
      # TODO doesn't work env.logger.debug(deviceConfigSchema)
      @conf = convict(_.cloneDeep(deviceConfigSchema))
      @conf.load(deviceConfig)
      @conf.validate()

      @name      = deviceConfig.name
      @id        = deviceConfig.id
      @houseunit = deviceConfig.houseunit
      @host      = deviceConfig.host
      @port      = deviceConfig.port

      env.logger.debug("Initiated name='#{@name}', id='#{@id}', houseunit='#{@houseunit}', host='#{@host}', port='#{@port}'")

      @connection = @initConnection()
      @sendCommand(@connection, "st");

      super()

    # ####changeStateTo()
    #  
    # #####params:
    #  * `state`
    # 
    changeStateTo: (state) ->
      @sendCommand(@connection, "pl #{@houseunit} " + ( if state then "on" else "off" ))
      @_setState(state) # TODO remove when all output is handled well
     
    # ####initConnection()
    # 
    # TODO Be a bit more efficient with connections: 12 devices devided over 3 mochads results in 12 connections instead of 3..
    # TODO Recover self is connection is lost
    initConnection: ->
      connection = net.createConnection(@port, @host)

      connection.on 'connect', () ->
        env.logger.debug("Opened connection")
      
      connection.on 'data', ((data) ->
        for line in data.toString().split("\n")
            # env.logger.debug("Received: #{line}")

            # Handling "st" result
            #  example: 05/26 19:16:11 House P: 1=1
            #  example: 05/26 19:16:12 House P: 1=1,3=1
            if m = /^\d{2}\/\d{2}\s+(?:\d{2}:){2}\d{2}\s+House\s+([A-P]): ((?:\d{1,2}=[01],?)+)$/g.exec(line)
              house = m[1]
              if house is not @houseunit.substr(0,1) then return 
              for unit2status in m[2].split(",")
                  n = unit2status.split("=")
                  houseunit = house + n[0]
                  if houseunit is @houseunit
                      state = if parseInt(n[1], 10) is 1 then true else false
                      env.logger.debug("State of #{@houseunit} => #{state}");
                      @_setState(state)

            # Handling all-units-on/off
            #  example: 05/22 00:34:04 Rx PL House: P Func: All units on
            #  example: 05/22 00:34:04 Rx PL House: P Func: All units off
            else if m = /^\d{2}\/\d{2}\s+(?:\d{2}:){2}\d{2}\sRx\s+PL\s+House:\s+([A-P])\s+Func:\s+All\s+units\s+(on|off)$/g.exec(line)
              house = m[1]
              if house is not @houseunit.substr(0,1) then return 
              state = if m[2] is "on" then true else false
              env.logger.debug("State of #{@houseunit} => #{state}");
              @_setState(state)

            # TODO Handling simple on/off
            #  example: 05/27 20:50:05 Rx PL House: P Func: On
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
    sendCommand: (connection, command) ->
      connection.write(command + "\r\n")

  # ###Wrap up 
  myMochadPlugin = new MochadPlugin
  return myMochadPlugin
