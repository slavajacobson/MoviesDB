require 'data_mapper'
require 'dm-migrations'

DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/movies.db")

class Movie
  include DataMapper::Resource
  property :id,           Serial
  property :name,         String
  property :year,         String
  property :poster,		    String
  property :rating,		    Decimal
  property :location,	    Text
  property :lookup_type,  String
  property :season,       String
  property :episode,      String
  property :genre,        String
  property :plot,         Text
  property :language,     String
  property :length,       String
  property :mpaa_rating,  String
  property :trailer,      String
  property :url,          String
  property :cast,         Text
  property :hide,         Boolean
end

class Settings
  include DataMapper::Resource
  property :id,           Serial
  property :property,     String
  property :value,        Text
end

DataMapper.finalize

Settings.auto_upgrade!
Movie.auto_upgrade!
LOGGER.debug "SUCCESS: Loaded Database!"