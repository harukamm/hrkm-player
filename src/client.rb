#!/usr/bin/env ruby

require 'socket'
load 'constants.rb'

def main()
  if ARGV.size == 0
    raise "Not arg~"
  end

  socket = TCPSocket.open(PLAYER_HOST, PLAYER_PORT)
  begin
    ARGV.each do |argv|
      sleep 0.5 # TODO: Remove after implementing operation queues~
      socket.puts argv
    end
  rescue IOError => e
    puts e.message
    puts e.backtrace
  ensure
    socket.close
  end

  puts "Just sent ^-^"
end

main
