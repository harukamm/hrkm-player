#!/usr/bin/env ruby

require 'socket'
require 'json'

def assert(v)
  if !v
    puts caller
    raise 'Assertion failed'
  end
end

def submit_log(host, port, type, log)
  data = {:data => log,
          :type => type,
          :timestamp => Time.new}
  data = JSON.generate(data)
  socket = TCPSocket.open(host, port)
  begin
    socket.puts data
  rescue IOError => e
    puts e.message
    puts e.backtrace
  ensure
    socket.close
  end
end
