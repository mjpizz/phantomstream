# phantomstream

Write and automate [PhantomJS](http://phantomjs.org) scripts inside node, using
a standard [Stream](http://nodejs.org/api/stream.html) interface.

# Getting Started

First off, install the `phantomstream` module.

    npm install phantomstream

Next, create a simple script named "myscript.js".

```javascript
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
```

Run your script with node.

    node myscript.js

...you should see output like this:

    [phantom-stdout] opening http://www.google.com
    [phantom-stdout] sending title = Google
    node received: Google

Enjoy! For more ideas on what is possible inside the callback for
`phantomstream.open()`, read the
[PhantomJS documentation](http://code.google.com/p/phantomjs/wiki/Interface).

Don't forget try out some demos from the `examples/` directory :)

# Alternatives

If you are looking for higher-level implementations that wrap the PhantomJS API,
check these out:

* [phantomjs-node](https://github.com/sgentle/phantomjs-node)
* [node-phantomjs-sync](https://github.com/sebv/node-phantomjs-sync)
