# Dummy server, run with '$ coffee dummy_server.coffee'
HOST = '127.0.0.1'
PORT = 1099

net = require('net')

net.createServer((sock) ->
  console.log 'Got connection from: ' + sock.remoteAddress + ':' + sock.remotePort
  sock.on 'data', (data) ->
    lines = data.toString()

    if /^st$/m.exec(lines)
      console.log 'Got data "st"'
      sock.write '06/04 21:50:55 Device status' + '\n' + '06/04 21:50:55 House P: 1=1,2=0,3=1,4=0,5=1,6=0,7=0,8=0,9=0,10=0,11=0,12=0,13=0,14=0,15=0,16=0' + '\n'

).listen PORT, HOST

console.log 'Server listening on ' + HOST + ':' + PORT
