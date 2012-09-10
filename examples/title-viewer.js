phantomstream = require("../phantomstream")

// Open up a PhantomJS stream that listens for commands that look like
// "TITLE <url>". Browse to the URL and write the title back via the stream.
var conf = {logger: console}
var ps = phantomstream.open(conf, function(nodestream, phantom, require, global) {

  // This callback executes inside of PhantomJS, not node.  To see the API
  // available to you in PhantomJS, check out their documentation:
  // http://code.google.com/p/phantomjs/wiki/Interface
  var page = require("webpage").create()

  // Listen for the "TITLE <url>" commands via the streaming interface.
  nodestream.on("data", function(data) {
    var matches = /TITLE\s*(.+)/.exec(data)
    if (matches) {
      var url = matches[1]

      // Got a TITLE command, use the PhantomJS page object to browse
      // to that page, get the document title, and write it back to the stream.
      console.info("opening", url)
      page.open(url, function() {
        var title = page.evaluate(function() {
          return document.title
        })
        console.info("sending title =", title)
        nodestream.write(title)
      })
    }
  })

})

// Send an TITLE command to our PhantomJS process and echo the response.
ps.write("TITLE http://www.google.com")
ps.on("data", function(data) {
  console.info("node received:", data.toString())
  process.exit()
})
