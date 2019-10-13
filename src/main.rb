#!/usr/bin/env ruby

require 'securerandom'
require 'socket'

load 'constants.rb'
load 'stopwatch.rb'
load 'load_assets.rb'
load 'utils.rb'

$pid = nil
$player_pid = nil
$interrupting_operator = nil
$assets = []
$status = {:playing_index => -1,
           :filter => {},
           :repeat? => false,
           :repeat_all? => true,
           :random? => false,
           :stop? => false,
           :target_songs => [],
           :stopwatch => nil}
# TODO: lock global variable
# TODO: use queue to store the operators

def log(type='Log', text)
  puts "[#{type}] #{text}"
  submit_log(LOG_HOST, LOG_PORT, type, text)
end

def interrupt_now!(text)
  assert(!$interrupting_operator)

  $interrupting_operator = text
  kill_player_proc()
end

def gen_serv_thread()
  server = TCPServer.open(PLAYER_HOST, PLAYER_PORT)

  t = Thread.new(server) do |serv|
    log 'Server thread starts~'
    clients = []
    while true
      rs, _ = IO.select([server] + clients)

      if rs[0] == server
        clients.push(server.accept)
        next
      end

      conn = rs[0]
      text = conn.gets

      if text == nil
        clients.delete(conn)
        next
      end

      text = text.chomp
      log "Receive #{text}"
      interrupt_now!(text)
    end
  end
  return t
end

def kill_player_proc()
  return if ! $player_pid
  begin
    Process.kill(9, $player_pid)
  rescue => e
    log('Error', "Failed to kill pid #{pid} with error #{e}")
  end
end

def play_file(song)
  assert(!$player_pid)
  log "Playing #{song[:title]}"
  watch = $status[:stopwatch] || Stopwatch.new
  watch.stop
  offset = watch.elapsed_time.floor
  pid = spawn("ffplay \"#{song[:path]}\" -nodisp -loglevel -8 -autoexit -ss #{offset}")
  watch.stop
  $status[:stopwatch] = watch
  return pid
end

def play_pause()
  assert(!$player_pid)
  return spawn("tail -f /dev/null")
end

def matched?(pattern, str)
  return !pattern || str.downcase.include?(pattern.downcase)
end

def target_songs()
  songs = []
  filter = $status[:filter]
  $assets.each do |artist|
    next if !matched?(filter[:artist], artist[:name])
    artist[:albums].each do |album|
      next if !matched?(filter[:album], album[:title])
      album[:songs].each do |song|
         next if !matched?(filter[:song], song[:title])
         songs.push(song)
      end
    end
  end
  songs.shuffle! if $status[:random?]
  return songs
end

def play_current_song()
  songs = $status[:target_songs]
  index = $status[:playing_index]
  assert(songs[index])

  if $status[:stop?]
    $player_pid = play_pause()
  else
    $player_pid = play_file(songs[index])
  end
  Process.wait $player_pid
  $player_pid = nil
end

def handle_random()
  current_song = $status[:target_songs][$status[:playing_index]]
  assert(current_song)

  newval = !$status[:random?]
  $status[:random?] = newval
  newsongs = target_songs()
  newindex = newsongs.index { |song| song[:id] == current_song[:id] }

  if newval
    current_song_ = newsongs[newindex]
    newsongs[newindex] = newsongs[0]
    newsongs[0] = current_song_
    newindex = 0
  end
  $status[:playing_index] = newindex
  $status[:target_songs] = newsongs
end

def handle_filter(query)
  filter = {}
  query.split(/:/).each do |q|
    next if q.size < 3
    type = q[0]
    val = q[1..-1]
    log "Filter #{type}, #{val}"
    case type
      when 'a'
        filter[:artist] = val
      when 'b'
        filter[:album] = val
      when 't'
        filter[:song] = val
    end
  end
  $status[:filter] = filter if filter != {}
  $status[:target_songs] = target_songs()
  $status[:playing_index] = 0
  $status[:stopwatch] = nil
end

def handle_interrupting_operator()
  op = $interrupting_operator
  if op == "next"
    $status[:playing_index] += 1
    $status[:stopwatch] = nil
  elsif op == "prev"
    $status[:playing_index] -= 1
    $status[:stopwatch] = nil
  elsif op == "stop"
    $status[:stop?] = !$status[:stop?]
    $status[:stopwatch].stop if $status[:stopwatch]
  elsif op == "rept"
    $status[:repeat?] = !$status[:repeat?]
  elsif op == "rand"
    handle_random()
  elsif op.start_with?("fltr")
    handle_filter(op[4..-1])
  else
    log('Warn', "Failed to handle unknown operator #{op}")
  end
end

def validate_status()
  index = $status[:playing_index]
  size = $status[:target_songs].size
  if index < 0
    index = 0
  elsif size == 0 || size <= index && !$status[:repeat_all?]
    $status[:stop?] = true
  else
    index %= $status[:target_songs].size
  end
  $status[:playing_index] = index
end

def start()
  while true do
    sleep(0.1)
    play_current_song()

    if $interrupting_operator
      handle_interrupting_operator()
      $interrupting_operator = nil
    else
      $status[:playing_index] += $status[:repeat?] ? 0 : 1
      $status[:stopwatch] = nil
    end
    validate_status()
    cloned = $status.clone
    cloned.delete(:target_songs)
    log "End of unit #{cloned}"
  end
end

def init()
  $assets = load_assets(DIR_ASSETS)
  $status[:playing_index] = 0
  $status[:target_songs] = target_songs()
  # log "Assets #{$assets}"
end

def main()
  Process.setsid
  init()
  begin
    thread = gen_serv_thread()
    start()
    thread.join()
  rescue => e
    log('Error', "#{e}, #{e.backtrace}")
    kill_player_proc()
  end
end

main()
