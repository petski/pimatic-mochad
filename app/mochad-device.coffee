$(document).on( "pagebeforecreate", (event) ->

  class MochadDimmerItem extends pimatic.SwitchItem

    getTemplateName: -> "mochad-dimmer"

    constructor: (data) ->
      super(data)
      # Do something, after create: console.log(this)
    afterRender: (elements) ->
      super(elements)

    onShutterDownClicked: ->
      @_ajaxCall('dim')

    onShutterUpClicked: ->
      @_ajaxCall('brighten')

    _ajaxCall: (deviceAction) ->
      pimatic.loading "switch-on-#{@switchId}", "show", text: __("switching #{@switchState()}")
      @device.rest[deviceAction]({}, global: no)
        .done(ajaxShowToast)
        .fail( =>
          @switchState(restoreState)
          pimatic.try( => @sliderEle.flipswitch('refresh'))
        ).always( =>
          pimatic.loading "switch-on-#{@switchId}", "hide"
          # element could be not existing anymore
          pimatic.try( => @sliderEle.flipswitch('enable'))
        ).fail(ajaxAlertFail)

  pimatic.MochadDimmerItem = MochadDimmerItem
  pimatic.templateClasses['mochad-dimmer'] = MochadDimmerItem
)
