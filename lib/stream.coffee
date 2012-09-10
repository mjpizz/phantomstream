fs = require("fs")
path = require("path")
http = require("http")
spawn = require("child_process").spawn
EventEmitter = require("events").EventEmitter
temp = require("temp")

PHANTOMJS_PATH = path.resolve(__dirname, "../ext")
PHANTOMJS_SERVER_PORT = 9999

getPhantomScript = (options) ->
  func = (options) ->

    # Create a stream that uses stdout for outbound data, and the builtin
    # phantomjs webserver for inbound data.
    listeners = {}
    emit = (event) ->
      args = Array.prototype.slice.call(arguments, 1)
      (listeners[event] or []).forEach (listener) ->
        listener.apply(listener, args)
    stream =
      write: (data) ->
        console.info("#{options.stdoutDataPrefix}#{JSON.stringify(data)}")
      on: (event, callback) ->
        (listeners[event] or= []).push(callback)
    server = require("webserver").create()
    server.listen options.port, (req, res) ->
      emit("data", req.post)
      res.writeHead(200, {"Content-Length": 0})
      res.write("")
      res.close()

    # Pass the stream to the bootstrap script.
    # TODO: shadow all globals to force explicit use of window object
    bootstrap = new Function("(#{options.bootstrap}).apply({}, arguments)")
    bootstrap(stream, phantom, require, window)

    # Indicate to node that the phantomjs process is ready by writing
    # some data to it.
    stream.write("READY")

  # Serialize the options for `func`, which will be stringified and opened
  # as a script by the phantomjs child process.
  optionsString = JSON.stringify options, (key, value) ->
    if typeof value is "function"
      return value.toString()
    else
      return value
  return "(#{func})(JSON.parse(#{JSON.stringify(optionsString)}))"

open = (options, bootstrap) ->
  options or= {}
  if typeof options is "function" and not bootstrap
    bootstrap = options
    options = {}
  logger = options.logger or {}
  # TODO: just find an open port instead
  phantomServerPort = PHANTOMJS_SERVER_PORT
  stdoutDataPrefix = "DATA#{Math.random().toString().slice(2)}:"
  phantomOptions =
    port: phantomServerPort
    stdoutDataPrefix: stdoutDataPrefix
    bootstrap: bootstrap

  # Build a tempfile that contains our phantomjs script.
  temp.open {prefix: "phantomstream", suffix: ".js"}, (err, info) ->
    if err
      logger.error?(err)
      return
    fs.write(info.fd, getPhantomScript(phantomOptions))
    fs.close info.fd, (err) ->
      if err
        logger.error?(err)
        return

      # Start phantomjs with the phantomjs script we defined.
      phantomBinPath = path.resolve(PHANTOMJS_PATH, "phantomjs")
      phantomProcess = spawn(phantomBinPath, [info.path])
      phantomProcess.stderr.on "data", (data) ->
        lines = data.toString.split()
        for own line in lines
          logger.info?("[phantom-stderr]", line) unless /^\s*$/.test(line)

      # The phantomjs process uses stdout for outbound data, so make sure we
      # differentiate between these data messages and normal logging.
      phantomProcessIsReady = false
      phantomProcess.stdout.on "data", (data) ->
        lines = data.toString().split("\n")
        for own line in lines
          if line.slice(0, stdoutDataPrefix.length) is stdoutDataPrefix

            # If the phantomjs process is already ready, then use
            # the rest of this line as the data.
            if phantomProcessIsReady
              try
                encodedData = line.slice(stdoutDataPrefix.length)
                emitter.emit("data", new Buffer(JSON.parse(encodedData)))
              catch err
                logger.error?("unable to parse data from phantomjs: #{encodedData}")

            # Otherwise, the first chunk of data simply indicates that
            # the phantomjs process is ready to receive data.
            else
              phantomProcessIsReady = true
              emitter.emit("ready")

          # All other stdout should be propagated to the console.
          else
            logger.info?("[phantom-stdout]", line) unless /^\s*$/.test(line)

      # Ensure that the child process is cleaned up on exit.
      cleanedUp = false
      cleanup = (err) ->
        unless cleanedUp
          cleanedUp = true
          phantomProcess.kill()
      cleanupAndExit = (err) ->
        if err
          logger.error?("[phantom-system] exiting due to error:", err)
        if daemonExited
          process.exit()
        else
          phantomProcess.on("exit", -> process.exit())
          process.nextTick(cleanup)
      process.on("exit", cleanup)
      process.on("uncaughtException", cleanupAndExit)
      process.on("SIGINT", cleanupAndExit)
      process.on("SIGTERM", cleanupAndExit)

  # http://nodejs.org/api/stream.html#stream_readable_stream
  # TODO: implement other events
  readyForWriting = false
  encoding = null
  emitter = new EventEmitter()
  stream =
    readable: true
    writeable: true
    on: (event, callback)->
      if event is "data"
        emitter.on "data", (buffer) ->
          # TODO: implement real encoding
          if encoding
            callback(buffer.toString())
          else
            callback(buffer)
    setEncoding: (e) ->
      encoding = e
    write: (data) ->
      performWrite = ->
        req = http.request({port: phantomServerPort, method: "POST"})
        req.on "error", (err) ->
          logger.error?(err)
        req.setHeader("Content-Length", data.length)
        req.end(data)
      if readyForWriting
        performWrite()
      else
        emitter.on "ready", ->
          readyForWriting = true
          performWrite()
  return stream

exports.open = open

if module is require.main
  stream = open {logger: console}, (stream, webpage) ->

    # Right now, just echo back any data received to show that this is working.
    # TODO: use dnode?
    stream.on "data", (data) ->
      console.info("RECV", data)
      stream.write("echoing back = #{data}")

  console.info("CLIENT: SEND: hello world")
  stream.write("hello world")
  stream.setEncoding("utf-8")
  stream.on "data", (data) ->
    console.info("CLIENT: RECV: #{data}")
