http = require("http")
phantomstream = require("../phantomstream")

// Run a webserver that just outputs "Hello!" and a global Javascript variable.
var webserver = http.createServer(function(req, res) {
  res.end("<h1>Hello!</h1><script>window.goodbye = 'Goodbye!'</script>")
})
webserver.listen(8080)
process.on("uncaughtException", function(err) {
  console.error(err)
  webserver.close()
  process.exit()
})

// Run PhantomJS and connect to this webserver to test its HTML output.
// This function runs inside of the PhantomJS context, not inside of node.
// http://code.google.com/p/phantomjs/wiki/Interface
var ps = phantomstream.open(function(nodestream, phantom, require, global) {

  // When the page finishes loading, check the HTML and Javascript values and
  // write the pass/fail result to the stream.
  var page = require("webpage").create()
  page.onLoadFinished = function() {
    var helloValue = page.evaluate(function() {
      return document.getElementsByTagName("h1")[0].innerHTML
    })
    var goodbyeValue = page.evaluate(function() {
      return window.goodbye
    })
    if (helloValue === "Hello!" && goodbyeValue === "Goodbye!") {
      nodestream.write("pass")
    } else {
      nodestream.write("fail")
    }
  }
  page.open("http://localhost:8080")

})

// Read the results from the phantomstream so we can output pass/fail.
ps.on("data", function(data) {
  if (data.toString() === "pass") {
    console.info("PASSED :)")
  } else {
    console.info("FAILED :(")
  }
  process.exit()
})
