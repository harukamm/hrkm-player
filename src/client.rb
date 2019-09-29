#!/usr/bin/env ruby

require 'socket'

def main()
  if ARGV.size != 1
    raise "Not arg~"
  end

  socket = UDPSocket.new
  socket.send(ARGV[0], 0, 'localhost', 8098)
  socket.close

  puts "Just sent ^-^"
end

main
