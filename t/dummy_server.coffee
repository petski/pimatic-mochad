# Dummy server, run with '$ coffee dummy_server.coffee'
HOST = '127.0.0.1'
PORT = 1099

net = require('net')

mochadDateTime = (date) ->
 ('0' + (date.getMonth() + 1)).slice(-2) + '/' + ('0' + date.getDate()).slice(-2) + ' ' + ('0' + date.getHours()).slice(-2) + ':' + ('0' + date.getMinutes()).slice(-2) + ':' + ('0' + date.getSeconds()).slice(-2)

net.createServer((sock) ->
  console.log 'Got connection from: ' + sock.remoteAddress + ':' + sock.remotePort
  sock.on 'data', (data) ->
    lines = data.toString()

    d = new Date

    if m = /^(st)$/m.exec(lines)
      console.log 'Got data "' + m[0] + '"'
      # 06/04 21:50:55 Device status
      # 06/04 21:50:55 House P: 1=1,2=0,3=1,4=0,5=1,6=0,7=0,8=0,9=0,10=0,11=0,12=0,13=0,14=0,15=0,16=0
      # 06/04 21:50:55 Security sensor status
      sock.write mochadDateTime(d) + ' Device status' + '\n' + '06/04 21:50:55 House P: 1=1,2=0,3=1,4=0,5=1,6=0,7=0,8=0,9=0,10=0,11=0,12=0,13=0,14=0,15=0,16=0' + '\n'

    if m = /^(pl|rf) ([a-pA-P])(\d{1,2}) (on|off)$/m.exec(lines)
      console.log 'Got data "' + m[0] + '"'
      if m[1] is "rf"
        # 11/30 17:57:12 Tx RF HouseUnit: A10 Func: On
        # 11/30 17:57:24 Tx RF HouseUnit: A10 Func: Off
        sock.write mochadDateTime(d) + ' Tx ' + m[1].toUpperCase() + ' HouseUnit: ' + m[2] + m[3] + ' Func: ' + m[4].substr(0, 1).toUpperCase() + m[4].substr(1) + '\n'
      if m[1] is "pl"
        # 05/30 20:59:20 Tx PL HouseUnit: P1
        # 05/30 20:59:20 Tx PL House: P Func: On
        sock.write mochadDateTime(d) + ' Tx ' + m[1].toUpperCase() + ' HouseUnit: ' + m[2] + m[3] + '\n'
        sock.write mochadDateTime(d) + ' Tx ' + m[1].toUpperCase() + ' House: ' + m[2] + ' Func: ' + m[4].substr(0, 1).toUpperCase() + m[4].substr(1) + '\n'

).listen PORT, HOST

console.log 'Server listening on ' + HOST + ':' + PORT
