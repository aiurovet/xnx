enum ConfigResult {
  ok, // continue as normal
  okEndOfList, // exit from the list's parent, then continue as normal
  run, // ready to run command
  stop, // stop immediately with an optional message
}
