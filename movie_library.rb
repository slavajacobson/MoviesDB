require 'imdb'
require 'open-uri'
require 'sqlite3'
require 'osdb'

SUPPORTED_EXTENSIONS = "mp4,mkv,mpeg,mpg,avi,m4v"

class MovieLibrary



	def initialize

    @fileSizeFilter = 457554880

    @server = OSDb::Server.new(
        :host => 'api.opensubtitles.org',
        :path => '/xml-rpc',
        :timeout => 60,
        :useragent => 'OS Test User Agent'
    )

    unless ENV["OCRA_EXECUTABLE"].nil?
      Dir.chdir(File.dirname(ENV["OCRA_EXECUTABLE"]))
    else

      Dir.pwd
    end

    @app_dir = Dir.pwd
    if Dir["public"].empty?

      Dir.mkdir("public")
    end


    if Dir["public/posters"].empty?

      Dir.mkdir("public/posters")
    end


	end


	def saveImageURL(url, name, out)

    poster_location_relative = 'posters/' + name.gsub(/[^0-9A-Za-z\s]/, '') + '.jpg'

		poster_location = @app_dir + '/public/posters/' + name.gsub(/[^0-9A-Za-z\s]/, '') + '.jpg'

    if !(File.exists?(poster_location)) || File.stat(poster_location).size == 0
      send_to_client out, %Q[data: { "status_info":"Downloading poster..." }\n\n]

      File.open(poster_location, 'wb') do |fo|
        begin
          fo.write open(url).read
          system(%Q[mogrify -resize 200x260 -quality 70 -format #{File.extname(poster_location).gsub('.','').upcase} "#{poster_location}"])
        rescue
          puts "Couldn't save poster from url: #{url}"
        end
      end
    else
      puts "Poster exists.. Skipping poster..."
    end



		poster_location_relative
	end

 	def getName(opt)
    movie_folder = opt[:path]
    type = opt[:type]

    i = movie_folder.rindex("/")

    if (type == 'folder')
      movie_folder = parentDir movie_folder
    elsif (type == 'file')
      movie_folder = File.basename(movie_folder)
    end

 		regexpr = /^[a-zA-Z.\s&-']+/
 		name = movie_folder[regexpr]

 		name.strip! unless name.nil?

    year = movie_folder[/\d{4}[^\w]/]
    
    unless name.nil?

      name = name.strip.gsub("."," ")
      
      name = name + " #{year[0..3]}" unless year.nil?

      puts "extracted name: #{name}"
    else
      name = movie_folder
    end

    name
  end

  #returns the parent folder of absolute location
  def parentDir (location)
    location = location.split("/")
    location[location.length - 2]
  end

 	def getYear(movie_folder)
 		year = movie_folder[/[\d]{4}/]
 		year
 	end

  def scan_for_broken_links
    Movie.all.each do |movie|
      unless File.exists?(movie.location)
        puts movie.location
        movie.destroy
      end
    end
  end

  def getTotalFiles
    count = 0
    movie_folder = Settings.first_or_create(property:"movies_folder").value

    Dir.glob("#{movie_folder}/**/*.{#{SUPPORTED_EXTENSIONS}}") do |movie_file|
      #if the file has non english characters, go to the next file
      #next if nonroman movie_file


      #only analyze files that are bigger than 50 megabytes
      if File.stat(movie_file).size > @fileSizeFilter
        count += 1
      end


    end

    count
  end

 	def populateDB out
    movies_folder = Settings.first_or_create(property:"movies_folder").value

    $scan_keep_going = true
		
    i = 0
    totalFiles = getTotalFiles

    send_to_client out, %Q[data: { "percent_completed": "0%", "file_number":"#{i}", "total":"#{totalFiles}", "status_info":"Starting process..." }\n\n]

    puts "folder: #{movies_folder} supported extensions: #{SUPPORTED_EXTENSIONS}"

    Dir.glob("#{movies_folder}/**/*.{#{SUPPORTED_EXTENSIONS}}") do |movie_file|
      break if $scan_keep_going == false

      #only analyze files that are bigger than 450 megabytes
      if File.stat(movie_file).size > @fileSizeFilter
        puts "--------------------------processing file: #{movie_file}"

        #if movie doesn't already exist in the database, collect its information and save
        unless movieExistsInDB? movie_file
          #look up movie's hash
          hasher = Hasher.new
          hash_movie = hasher.open_subtitles_hash(movie_file)
          
          #look up the hash in OSDB and retrieve IMDB ID
          begin
            send_to_client out, %Q[data: { "status_info":"Identifying movie file...", "filename_info":"#{movie_file}" }\n\n]
            osDBLookUp = @server.check_movie_hash(hash_movie)['data'][hash_movie]
            retryConnect = 0

          rescue
            retryConnect = 0 if retryConnect.nil?
            retryConnect += 1

            puts "-----------------------EOF ERROR!! reinstantiating the server and redoing iteration------------ retry #{retryConnect}"
            @server =     OSDb::Server.new(
                :host => 'api.opensubtitles.org',
                :path => '/xml-rpc',
                :timeout => 60,
                :useragent => 'OS Test User Agent'
            )

            if retryConnect < 3
              i -= 1
              sleep 1
              redo
            else
              retryConnect = 0
              next
            end

          end


          if !osDBLookUp.nil? && !osDBLookUp.empty? #Lookup hash in OSDB
            lookup_id_and_save movie_file, osDBLookUp, out

          else #Parse folder name
            parse_and_save movie_file, out
          end

        end

        #Send the percentage completion to the client
        i += 1
        completed_percentage = (i.to_f / totalFiles.to_f * 100).round(2).to_s
        send_to_client out, %Q[data: { "percent_completed": "#{completed_percentage}%", "file_number":"#{i}", "total":"#{totalFiles}", "file":"#{movie_file}" }\n\n]


      end
    end


    if $scan_keep_going
      send_to_client out, %Q[data: { "completed": "true" }\n\n]
      puts "Done!"
    else
      send_to_client out, %Q[data: { "status_info": "Process paused" }\n\n]
 
    end
      


	end


  def lookup_id_and_save movie_file, osDBLookUp, out
    puts "found in OSDB: " + osDBLookUp["MovieName"]

    #skip TV series
    if osDBLookUp["MovieKind"] == "episode" || osDBLookUp["MovieKind"] == "tv series"
      Movie.create!(location:movie_file, hide:true)

    else
      puts "inspect: " + osDBLookUp.inspect
      puts "---------------"

      imdbID = osDBLookUp["MovieImdbID"]

      
      send_to_client out, %Q[data: { "status_info":"Collecting movie's information" }\n\n]

      imdbMovie = Imdb::Movie.new(imdbID)



      puts "imdb inspect: #{imdbMovie.inspect}"


      

      if imdbMovie.title.nil?
        parse_and_save movie_file, out

      elsif (imdbMovie.title.downcase.include?("tv series") || imdbMovie.genres.join(" ").downcase.include?("short"))
        Movie.create!(location:movie_file, hide: true)
      else

        begin
          local_image = saveImageURL(imdbMovie.poster, imdbMovie.title, out) unless imdbMovie.poster.nil?

        rescue Exception => e
          local_image = ""
          puts "--------------FAILED TO SAVE POSTER----------------------------"
        end

        begin
         
          Movie.create!(url: imdbMovie.url , genre: imdbMovie.genres.join(" "), name:imdbMovie.title, year: imdbMovie.year, poster:local_image, rating:imdbMovie.rating.to_f, plot: imdbMovie.plot, cast: imdbMovie.cast_members[0..8].join(" "),
                        location:movie_file, mpaa_rating: imdbMovie.mpaa_rating, language: imdbMovie.languages, length: imdbMovie.length, trailer: imdbMovie.length, lookup_type:"osdb", hide: false)

        rescue Exception => e
          puts "-------------1FAILED DB insert: #{e.inspect}"
        end

      end
    end
  end

  def parse_and_save movie_file, out
    
    send_to_client out, %Q[data: { "status_info":"Collecting movie's information" }\n\n]

    imdbMovie = imdb_search_name(getName(path: movie_file, type: 'folder')) || imdb_search_name(getName(path: movie_file, type: 'file'))
    

    if !imdbMovie.nil? && (imdbMovie.title.downcase.include?("tv series") || imdbMovie.genres.join(" ").downcase.include?("short"))
      Movie.create!(location:movie_file, hide: true)
    elsif !imdbMovie.nil?

      local_image = saveImageURL(imdbMovie.poster, imdbMovie.title, out) unless imdbMovie.poster.nil?

      begin
        Movie.create!(genre: imdbMovie.genres.join(" "), name:imdbMovie.title, year: imdbMovie.year, poster:local_image, rating:imdbMovie.rating.to_f, plot: imdbMovie.plot, cast: imdbMovie.cast_members[0..8].join(" "),
         location:movie_file, mpaa_rating: imdbMovie.mpaa_rating, language: imdbMovie.languages, length: imdbMovie.length, trailer: imdbMovie.length, lookup_type:"regex", hide: false)
      rescue Exception => e
        puts "-------------2FAILED DB insert: #{e.inspect}"
      end



    else
        
      begin
        puts "INSERTING UNKNOWN ------ #{movie_file}"
        Movie.create!(name:getName(path: movie_file, type: 'file'), location:movie_file, lookup_type:"regex", hide: true)
      
      rescue Exception => e
        puts "-------------3FAILED DB insert: #{e.inspect}"
      end

    end
  end




  def imdb_search_name name
    search = Imdb::Search.new(name)
    keep_going = true
    movie = nil
    while keep_going

      begin
        movie = search.movies[0]
        keep_going = false
      rescue Exception => e
        LOGGER.debug "Failed to retrieve IMDB movie: #{e}"
      end
    end

    movie
  end

  def send_to_client out, data
    begin
      out << data
    rescue Exception => e
      LOGGER.debug "Send to client ERROR: #{e}"
    end
  end

	#create a DB and tables if necessary

  #returns true if movie was already inserted into db
  def movieExistsInDB?(location)
    puts "checking if movie exists in DB: #{location}"
    result = Movie.first(location:location)
    if result.nil?
      puts "MOVIE DOESNT EXIST -----------------"
    else
      puts "MOVIE EXISTS ---------------------"
    end
    not result.nil?
  end


  def nonroman (str)
    (/^[\w\s!@#\$%\^\\&*()\]\[,.:\/-]*$/ =~ str) == nil
  end




end


class Hasher

  def open_subtitles_hash(filename)
    raise "Need video filename" unless filename

    fh = File.open(filename)
    fsize = File.size(filename)

    hash = [fsize & 0xffff, (fsize >> 16) & 0xffff, 0, 0]

    8192.times { hash = add_unit_64(hash, read_uint_64(fh)) }

    offset = fsize - 65536
    fh.seek([0,offset].max, 0)

    8192.times { hash = add_unit_64(hash, read_uint_64(fh)) }

    fh.close

    return uint_64_format_hex(hash)
  end

  def read_uint_64(stream)
    stream.read(8).unpack("vvvv")
  end

  def add_unit_64(hash, input)
    res = [0,0,0,0]
    carry = 0

    hash.zip(input).each_with_index do |(h,i),n|
      sum = h + i + carry
      if sum > 0xffff
        res[n] += sum & 0xffff
        carry = 1
      else
        res[n] += sum
        carry = 0
      end
    end
    return res
  end

  def uint_64_format_hex(hash)
    sprintf("%04x%04x%04x%04x", *hash.reverse)
  end
end




