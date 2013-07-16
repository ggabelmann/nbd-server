fs = require('fs')
net = require('net')
util = require('util')
whenjs = require('when')
request = require('request')

INIT_PASSWD = 'NBDMAGIC'
INIT_MAGIC = '0000420281861253' # hex
REQUEST_MAGIC = '25609513' # hex
REPLY_MAGIC = '67446698' # hex

REQUEST_READ = 0
REQUEST_WRITE = 1
REQUEST_DISCONNECT = 2

MAX = Math.pow(2, 52) # 4 PiB. Javascript max int is 2^53, but this makes our life easier below.

process.on('uncaughtException', (err) ->
   console.log(util.inspect(err))
)

argServerPort = process.argv[2] # eg 8124
argProtocol   = process.argv[3] # eg fs or http
argPath       = process.argv[4] # eg /home/jdoe/disk-image or http://example.com:80/disk-image

class FsDiskImage
   constructor: (@path) ->

   close: () ->
      fs.closeSync(@fd)

   getSize: () ->
      return whenjs.promise((resolve, reject, notify) => # fat arrow!
         fs.fstat(@fd, (error, stats) ->
            resolve(stats.size)
         )
      )

   open: () ->
      @fd = fs.openSync(@path, 'r')

   read: (from, length) ->
      return whenjs.promise((resolve, reject, notify) => # fat arrow!
         buffer = new Buffer(length)
         fs.read(@fd, buffer, 0, length, from, (err, bytesRead, callbackBuffer) ->
            resolve(callbackBuffer)
         )
      )

class HttpDiskImage
   constructor: (@uri) ->

   close: () ->

   getSize: () ->
      whenjs.promise((resolve, reject, notify) => # fat arrow!
         request.head(@uri, (error, response) ->
            # Need to check the statusCode here!
            resolve(response.headers['content-length'])
         )
      )

   open: () ->

   read: (from, length) ->
      whenjs.promise((resolve, reject, notify) => # fat arrow!
         request({
               encoding: null # Necessary for body to be a Buffer
               headers:
                  range: 'bytes=' + from + '-' + (from + length - 1)
               uri: @uri
            },
            (error, response, body) ->
               # Need to check the statusCode here!
               resolve(body)
         )
      )

diskImage = null
diskImageSize = null

if (process.argv.length isnt 5)
   console.log('Wrong number of arguments.')
   process.exit()

switch argProtocol
   when 'fs'
      diskImage = new FsDiskImage(argPath)
      console.log('using filesystem')
   when 'http'
      diskImage = new HttpDiskImage(argPath)
      console.log('using http')
   else
      console.log('Wrong protocol.')
      process.exit()

server = net.createServer((connection) ->
   console.log('connected')
   buffer = new Buffer(8 + 8 + 8 + 128)
   buffer.write(INIT_PASSWD, 0, 8, 'utf8')
   buffer.write(INIT_MAGIC, 8, 8, 'hex')
   buffer.write(integerToPaddedHex(diskImageSize, 16), 16, 8, 'hex')
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
         console.log('Data request is not a multiple of 28 bytes.')
         connection.end()
   )

   connection.on('error', (error) ->
      console.log(error + ': error occured, closing connection.')
      connection.end() # Is end() automatically called for us when an error event is created?
   )
)

server.on('close', () ->
   diskImage.close()
   console.log('Closed the server')
)

server.on('listening', () ->
   console.log('Server listening on port 8124')
)

diskImage.open()
diskImage.getSize().then(
   (size) ->
      diskImageSize = size
      console.log('disk image size: ' + diskImageSize)
      if (0 <= diskImageSize <= MAX)
         server.listen(argServerPort)
      else
         console.log('The disk image is an unsupported size. Exiting.')
         server.close()
   (error) ->
      console.log(error)
      server.close()
)


# Utility functions


handleDataHelper = (connection, data) ->
   magic = data.toString('hex', 0, 4)
   type = data.readUInt32BE(4)
   handle = data.toString('hex', 8, 16)
   from = readUInt64BE(data.slice(16, 24))
   length = data.readUInt32BE(24)

   #console.log('request: ' + data.length + ' bytes')
   #console.log('magic: ' + magic)
   console.log('type: ' + type)
   console.log('handle: ' + handle)
   console.log('from: ' + from)
   console.log('length: ' + length)

   switch type
      when REQUEST_READ
         console.log('handle read')
         diskImage.read(from, length).then(
            (buffer) ->
               finalBuffer = new Buffer(4 + 4 + 8 + length)
               buffer.copy(finalBuffer, 16)
               finalBuffer.write(REPLY_MAGIC, 0, 4, 'hex')
               finalBuffer.write('00000000', 4, 4, 'hex')
               finalBuffer.write(handle, 8, 8, 'hex')
               connection.write(finalBuffer)
               console.log('done ' + handle)
          )

      when REQUEST_WRITE
         console.log('handle write')
         console.log('not supported')
         connection.end()

      when REQUEST_DISCONNECT
         console.log('handle close')
         connection.end()

integerToPaddedHex = (integer, length) ->
   hex = (new Number(integer)).toString(16) # Force it to be a number and then convert its base
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
