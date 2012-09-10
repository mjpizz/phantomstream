phantomstream = require("../phantomstream")

// Run PhantomJS and demonstrate how we can send data back and forth from
// the node process to the phantom process.
// http://code.google.com/p/phantomjs/wiki/Interface
var ps = phantomstream.open({logger: console}, function(nodestream, phantom, require, global) {

  nodestream.on("data", function(data) {
    console.info("phantom received:", data.toString())
    nodestream.write("goodbye moon")
  })

})
ps.write("hello world")
ps.on("data", function(data) {
  console.info("node received:", data.toString())
  process.exit()
})
