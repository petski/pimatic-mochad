pimatic-mochad
==============

Connects [pimatic](http://pimatic.org) to [mochad](http://sourceforge.net/apps/mediawiki/mochad)

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
      "unit": 1
    },  
    {
      "id": "light-living",
      "class": "MochadSwitch",
      "name": "Living Light",
      "unit": 2 
    }
  ]
}   
```
