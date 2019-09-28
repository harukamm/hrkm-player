#!/usr/bin/ruby

require 'securerandom'
require 'socket'

def assert(v)
  if !v
    raise 'Assertion failed'
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
$need_restart_loop = false
$assets = []
$settings = {:repeat? => false,
             :filter => nil,
             :random? => false}
$status = {:playing => "",
           :start_playing_at => "",}

def handle_operator(op)
  case op
  when "next"
    ""
  when "prev"
    ""
  when "setrand"
    ""
  else
    ""
  end
end

def gen_serv_thread()
  server = UDPSocket.new
  server.bind("localhost", 8098)

  t = Thread.new(server) do |serv|
    puts "[Log] Thread starts"
    while true
      text, sender = server.recvfrom(16)
      puts "[Log] Receive text #{text}"
      handle_operator()
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
  $player_pid = spawn("ffplay \"#{song[:path]}\" -nodisp -loglevel -8 -autoexit -ss 100")
end

def play_loop()
  # TODO: Apply the filter
  $assets[0][:albums][0][:songs].each do |song|
    play_file(song)
    Process.wait $player_pid
    $player_pid = nil
    if $need_restart_loop
      break
    end
  end
end

def start()
  while true do
    sleep(0.1)
    play_loop()
    break if !$need_restart_loop
  end
end

def init()
  $assets = load_assets()
end

def main()
  init()
  begin
    thread = gen_serv_thread()
    start()
    thread.join()
  rescue => e
    puts "[Error] #{e}"
  end
end

main()
