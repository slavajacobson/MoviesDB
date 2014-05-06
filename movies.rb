require 'rubygems'
require 'imdb'

search = Imdb::Search.new('Star Trek')
=> #<Imdb::Search:0x18289e8 @query="Star Trek">

puts search.movies[0..3].collect{ |m| [m.id, m.title].join(" - ") }.join("\n")
=> 0060028 - "Star Trek" (1966) (TV series)    
      0796366 - Star Trek (2009)    
      0092455 - "Star Trek: The Next Generation" (1987) (TV series)    
      0112178 - "Star Trek: Voyager" (1995) (TV series) 

st = Imdb::Movie.new("0796366")
=> #<Imdb::Movie:0x16ff904 @url="http://www.imdb.com/title/tt0796366/", @id="0796366", @title=nil>

st.title
=> "Star Trek"
st.year
=> 2009
st.rating
=> 8.4
st.cast_members[0..2].join(", ")
=> "Chris Pine, Zachary Quinto, Leonard Nimoy"


 test[/^[a-zA-Z.\s&-']+/]
name  = ^[a-zA-Z.\s&-']+ .gsub("."," ")
year = [\d]{4}
