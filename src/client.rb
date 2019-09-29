#!/usr/bin/env ruby

require 'socket'
load 'constants.rb'

def main()
  if ARGV.size != 1
    raise "Not arg~"
  end

  socket = UDPSocket.new
  socket.send(ARGV[0], 0, PLAYER_HOST, PLAYER_PORT)
  socket.close

  puts "Just sent ^-^"
end

main
