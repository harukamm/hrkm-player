#!/usr/bin/env ruby

require 'socket'

def assert(v)
  if !v
    puts caller
    raise 'Assertion failed'
  end
end

def submit_log(host, port, text)
  socket = TCPSocket.open(host, port)
  begin
    @socket.puts text
  rescue IOError => e
    puts e.message
    puts e.backtrace
  ensure
    socket.close
  end
end
