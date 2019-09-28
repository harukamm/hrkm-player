#!/usr/bin/ruby

require 'securerandom'
require 'socket'

def assert(v)
  if !v
    puts caller
    raise 'Assertion failed'
  end
end

#####################################################
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

#####################################################

DIR_ASSETS = "./assets"

def regular_dir?(path)
  return path[-1] != "." && path[-2..-1] != ".." && File.directory?(path)
end

def regular_file?(path)
  return path[-1] != "." && path[-2..-1] != ".." && File.file?(path)
end

def load_assets()
  assets = []
  song_id = 0
  Dir.open(DIR_ASSETS) do |artist_dirs|
    artist_dirs.each do |artist_dir|
      path1 = File.join(DIR_ASSETS, artist_dir)
      next if !regular_dir?(path1)

      albums = []
      Dir.open(path1).each do |album_dir|
        path2 = File.join(path1, album_dir)
        next if !regular_dir?(path2)

        album_songs = []
        track = 0

        Dir.open(path2).each do |song|
          path3 = File.join(path2, song)
          next if !regular_file?(path3)
          next if File.extname(path3) != ".mp3"
          song = {:title => File.basename(path3, ".*"),
                  :path  => path3,
                  :id => song_id,
                  :track_num => track}
          album_songs.push(song)
          track += 1
          song_id += 1
        end

        next if album_songs.size == 0

        album = {:title => album_dir,
                 :path => path2,
                 :songs => album_songs}
        albums.push(album)
      end

      next if albums.size == 0

      artist = {:name => artist_dir,
                :path => path1,
                :albums => albums}
      assets.push(artist)
    end
  end
  return assets
end

#####################################################

$pid = nil
$player_pid = nil
$interrupting_operator = nil
$assets = []
$status = {:playing_index => -1,
           :filter => {},
           :repeat? => false,
           :random? => false,
           :stop? => false,
           :target_songs => [],
           :stopwatch => nil}

def interrupt_now!(text)
  assert(!$interrupting_operator)

  $interrupting_operator = text
  kill_player_proc()
end

def gen_serv_thread()
  server = UDPSocket.new
  server.bind("localhost", 8098)

  t = Thread.new(server) do |serv|
    puts "[Log] Thread starts"
    while true
      text, sender = server.recvfrom(16)
      puts "[Log] Receive text #{text}"
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
    puts "[Error] Failed to kill pid #{pid} with error #{e}"
  end
end

def play_file(song)
  assert(!$player_pid)
  puts "[Log] Playing #{song[:title]}"
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
  puts filter
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
  puts $status[:random?]
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
    puts "[Log] Filter #{type}, #{val}"
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
  elsif op == "rand"
    handle_random()
  elsif op.start_with?("fltr")
    handle_filter(query)
  else
    puts "[Warn] Failed to handle unknown operator #{op}"
  end
end

def validate_status()
  index = $status[:playing_index]
  if index < 0
    index = 0
  elsif $status[:target_songs].size != 0
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
      $status[:playing_index] += 1
      $status[:stopwatch] = nil
    end

    validate_status()
  end
end

def init()
  $assets = load_assets()
  $status[:playing_index] = 0
  $status[:target_songs] = target_songs()
end

def main()
  init()
  begin
    thread = gen_serv_thread()
    start()
    thread.join()
  rescue => e
    puts e.backtrace
    puts "[Error] #{e}"
  end
end

main()
