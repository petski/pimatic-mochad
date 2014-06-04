pimatic-mochad
==============

Connects [pimatic](http://pimatic.org) to [mochad](http://sourceforge.net/apps/mediawiki/mochad)

#### Example usage

First, please note that you can switch units via RF (433 Mhz), powerline (PL) and via the mobile-frontend as well

Some cool rules:

```if it is 18:00 then turn Kitchen Light on```

~~```if it is after 23:00 and CM15Pro receives event:"RF all lights off" then push title:"Good nigth!" message:"Sleep well, sir!"```~~

~~```if CM15Pro receives event:"RF A9 on" then turn Kitchen Light off and turn Living Light on```~~

#### Contemplations

I've choosen [mochad](http://sourceforge.net/apps/mediawiki/mochad) over [node-x10](https://github.com/randallagordon/node-x10/) because mochad allows us to run pimatic on a different host as the X10 controller is attached to. For example, you can run your mochad instance on OpenWRT, while running pimatic on your [Raspberry Pi](http://raspberrypi.org). 

#### Configuration

Under "plugins" add:

```
{
  "plugin": "mochad"
}
```

Under "devices" add (something like):

```
{
  "id": "CM15Pro",
  "class": "Mochad",
  "name": "CM15Pro",
  "host": "192.168.1.11",
  "port": 1099,
  "house": "P",
  "units": [
    {
      "id": "light-kitchen",
      "class": "MochadSwitch",
      "name": "Kitchen Light",
      "code": 1
    },  
    {
      "id": "light-living",
      "class": "MochadSwitch",
      "name": "Living Light",
      "code": 2 
    }
  ]
}   
```
