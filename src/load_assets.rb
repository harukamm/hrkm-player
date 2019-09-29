#!/usr/bin/env ruby

def regular_dir?(path)
  return path[-1] != "." && path[-2..-1] != ".." && File.directory?(path)
end

def regular_file?(path)
  return path[-1] != "." && path[-2..-1] != ".." && File.file?(path)
end

def load_assets(dir_assets)
  assets = []
  song_id = 0
  Dir.open(dir_assets) do |artist_dirs|
    artist_dirs.each do |artist_dir|
      path1 = File.join(dir_assets, artist_dir)
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
