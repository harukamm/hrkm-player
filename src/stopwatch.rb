#!/usr/bin/env ruby

# Refer: https://gist.github.com/ikenna/6422329

class Stopwatch
  def initialize()
    @start = Time.now
    @stop = nil
  end

  def stop
    if @stop == nil # stop
      @stop = Time.now
    elsif # restart
      offset = @stop - @start
      @start = Time.now - offset
      @stop = nil
    end
  end

  def elapsed_time
    return Time.now - @start
  end
end
