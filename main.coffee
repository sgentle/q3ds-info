dgram = require "dgram"
EventEmitter = require('events').EventEmitter
PACKETS = 
  q3status: new Buffer ["0xFF", "0xFF", "0xFF", "0xFF", "0x67", "0x65", "0x74", "0x73", "0x74", "0x61", "0x74", "0x75", "0x73", "0x00"]
  q3info: new Buffer ["0xFF", "0xFF", "0xFF", "0xFF", "0x67", "0x65", "0x74", "0x69", "0x6E", "0x66", "0x6F", "0x00"]

class Q3DS extends EventEmitter
  constructor: (ip, port, options={}) ->
    return new Q3DS(ip, port, options) if this is global
    [@ip, @port, @options] = [ip, port, options]

    @client = dgram.createSocket 'udp4'
    @client.on 'message', cb = (msg, rinfo) =>
      return unless msg
      resps = msg.toString().split("\n")
      resps.shift()
      fields = resps.shift().split("\\")
      fields.shift()
      isnew = !@obj
      @obj = {} if isnew

      for k, i in fields by 2
        v = fields[i+1]
        v = parseInt v if isFinite v
        @obj[k] = v

      if resps.length > 0
        @obj.players = for p in resps
          split = p.split ' '
          continue unless split.length >= 3
          {score: parseInt(split.shift()), ping: parseInt(split.shift()), name: split.join(' ')}

      if !isnew
        @onMsg @obj
        delete @obj
      else
        setTimeout => 
          @send PACKETS.q3status, cb
        , 1000
        

    @options.timeout ||= 10000


  send: (packet, cb=->) ->
    @client.send packet, 0, packet.length, @port, @ip, (err) =>
      if err 
        cb err
      else
        #This is a bit crap - should figue out a way of matching responses to requests or queueing
        timeout = null
        msgcb = (msg) ->
          clearTimeout timeout
          cb null, msg
        
        @on 'message', msgcb
        
        timeout = setTimeout =>
          @removeListener 'message', msgcb
          cb new Error "Request timed out"
        , @options.timeout

  info: (cb) ->
    @send PACKETS.q3info, cb

  onMsg: (msg, rinfo) =>
    decoded = msg
    
    for old, _new of {
      mapname: "map"
      clients: "numPlayers"
      sv_maxclients: "maxPlayers"
      hostname: "serverName"
    }
      #console.log "old", old, "new", _new
      decoded[_new] = decoded[old]
      delete decoded[old]    

    decoded.numPlayers ?= 0

    @emit "message", decoded

  close: ->
    @client.close()

module.exports = Q3DS
