os = require("os")

get = ->
  if /darwin/i.test(os.platform())
    "macosx"
  else if /windows/i.test(os.platform())
    "windows"
  else if /linux/i.test(os.platform()) and /32/.test(os.arch())
    "linux32"
  else if /linux/i.test(os.platform()) and /64/.test(os.arch())
    "linux64"
  else
    null

exports.get = get