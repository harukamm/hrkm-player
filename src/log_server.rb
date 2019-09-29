#!/usr/bin/env ruby

require 'socket'
load 'constants.rb'

class LogServer
  def initialize(socket_address, socket_port)
    @server_socket = TCPServer.open(socket_address, socket_port)
    @clients = []
    log 'Started log server...'
    start
    @server_socket.close
  end

  def log(data)
    store "#{Time.new}, #{data}"
  end

  def store(data)
    puts "[Store] #{data}"
    open(LOG_FILE, 'a') { |f|
      f.puts data
    }
  end

  def start
    while true
      rs, _ = IO.select([@server_socket] + @clients)

      if rs[0] == @server_socket
        conn = @server_socket.accept
        log "Accept #{conn}"
        @clients.push(conn)
        next
      end

      conn = rs[0]
      text = conn.gets

      if text == nil
        log "Bye for now! #{conn}"
        @clients.delete(conn)
        next
      end

      text = text.chomp
      store text
      puts "Receive => #{text}"
    end
  end
end

LogServer.new(LOG_HOST, LOG_PORT)
