fs = require('fs')
net = require('net')
util = require('util')

INIT_PASSWD = 'NBDMAGIC'
INIT_MAGIC = '0000420281861253' # hex
REQUEST_MAGIC = '25609513' # hex
REPLY_MAGIC = '67446698' # hex

REQUEST_READ = 0
REQUEST_WRITE = 1
REQUEST_DISCONNECT = 2

MAX = Math.pow(2, 52) # 4 PiB. Javascript max int is 2^53, but this makes our life easier below.

# argv[3] is the path to the disk image
fd = fs.openSync(process.argv[3], 'r')
diskImageStats = fs.fstatSync(fd)
if (diskImageStats.size > MAX)
   console.log('The disk image is too big. Exiting.')
   fs.closeSync(fd)
   return;

server = net.createServer((connection) ->
   console.log('connected')
   buffer = new Buffer(8 + 8 + 8 + 128)
   buffer.write(INIT_PASSWD, 0, 8, 'utf8')
   buffer.write(INIT_MAGIC, 8, 8, 'hex')
   buffer.write(integerToPaddedHex(diskImageStats.size, 16), 16, 8, 'hex')
   buffer.fill('\u0000', 24)
   connection.write(buffer)

   connection.on('close', ->
      console.log('connection closed')
   )

   connection.on('data', (data) ->
      if data.length % 28 is 0
         for index in [0..data.length - 1] by 28
            handleDataHelper(connection, data.slice(index, index + 28))
      else
         console.log('data request is not 28 bytes.')
         connection.end()
   )

   connection.on('error', (error) ->
      console.log(error + ': error occured, closing connection.')
      connection.end() # Is end() automatically called for us?
   )
)

handleDataHelper = (connection, data) ->
   magic = data.toString('hex', 0, 4)
   type = data.readUInt32BE(4)
   handle = data.toString('hex', 8, 16)
   from = readUInt64BE(data.slice(16, 24))
   length = data.readUInt32BE(24)

   #console.log('request: ' + data.length + ' bytes')
   console.log('magic: ' + magic)
   console.log('type: ' + type)
   console.log('handle: ' + handle)
   console.log('from: ' + from)
   console.log('length: ' + length)

   switch type
      when REQUEST_READ
         console.log('handle read')
         buffer = new Buffer(4 + 4 + 8 + length)
         buffer.write(REPLY_MAGIC, 0, 4, 'hex')
         buffer.write('00000000', 4, 4, 'hex')
         buffer.write(handle, 8, 8, 'hex')
         fs.read(fd, buffer, 16, length, from, (err, bytesRead, callbackBuffer) ->
            connection.write(callbackBuffer)
            console.log('done ' + handle)
         )

      when REQUEST_WRITE
         console.log('handle write')
         console.log('not supported')
         connection.end()

      when REQUEST_DISCONNECT
         console.log('handle close')
         connection.end()

# argv[2] is the port to listen on
server.listen(process.argv[2])

server.on('close', ->
   console.log('closing file descriptor')
   fs.closeSync(fd)
)

server.on('listening', ->
   console.log('Server listening on port 8124')
)

process.on('uncaughtException', (err) ->
   console.log(util.inspect(err))
)


# Utility functions


integerToPaddedHex = (integer, length) ->
   hex = integer.toString(16)
   while (hex.length < length)
      hex = '0' + hex
   return hex

# Note: javascript integers are accurate from/to +/- 2^53 because Number is a 64 bit double.
readUInt64BE = (buffer) ->
   int = buffer[buffer.length - 1]
   mult = 256
   for index in [buffer.length - 2..0]
      int += (buffer[index] * mult);
      mult *= 256
   return int
