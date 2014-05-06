
require 'rubygems'
require "rexml/document"
require 'launchy'
require 'sinatra'
require "sinatra/streaming" # from Sinatra-contrib
require 'json'



require_relative 'logger.rb'
require_relative 'movies_db.rb'
require_relative 'movie_library.rb'
require_relative 'helpers/helpers.rb'


unless ENV["OCRA_EXECUTABLE"].nil?
  $app_dir = File.dirname(ENV["OCRA_EXECUTABLE"])
  Dir.chdir $app_dir
  set :public_folder, $app_dir
end

puts "RUNNING!!! #{File.dirname(__FILE__)}"





MOVIES = MovieLibrary.new
$scan_keep_going = false



exit if Object.const_defined?(:Ocra)


set :server, :thin


get '/filter' do

  puts params[:actor]
  @movies = Movie.all(:hide.not => true)
  @movies = @movies.all(:name.like => "%#{params[:title]}%", :genre.like => "%#{params[:genre]}%")
  @movies = @movies.all(:year.gte => params[:from_year]) unless params[:from_year].blank?
  @movies = @movies.all(:year.lte => params[:to_year]) unless params[:to_year].blank?
  @movies = @movies.all(:cast.like => "%#{params[:actor]}%") unless params[:actor].blank?
  @movies = @movies.all(:mpaa_rating.like => "%#{params[:mpaa_rating]}%") unless params[:mpaa_rating].blank?

  erb :movies, :layout => false
end

get '/app_live', provides: 'text/event-stream' do
  stream do |out|
    while true

      begin
        out << "ping"
        sleep 5
      rescue
        exit!
      end

    end
  end 
end

get '/scan_movies', :provides => 'text/event-stream'  do

  stream do |out|
    MOVIES.populateDB out
  end
end

get '/exit' do
  exit!
end

get '/delete_broken_links' do
  MOVIES.scan_for_broken_links
end

get '/pause_sync_movies' do
  $scan_keep_going = false
end

post '/clear_db', :provides => 'text/event-stream'  do
  Movie.all.destroy!
end

post '/settings' do

  Settings.first_or_create(property:"movies_folder").update(value:params[:movies_folder].gsub("\\","/").chomp('/'))
  puts "saving value: #{params[:movies_folder].gsub("\\","/").chomp('/')}"
end

get '/' do  

	@movies_folder = Settings.first_or_create(property:"movies_folder").value

  puts @movies_folder
	erb :index  
end 


post '/play' do 
  @movie = Movie.get(params[:id])
  system(%Q[start "" "#{@movie.location}"]) 
end



Launchy.open("http://localhost:4567/")




