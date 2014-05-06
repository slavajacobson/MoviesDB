require 'base64'

helpers do
  def base64_url(path)
	    begin
	    	file = File.open(path, "rb")

			b64 = Base64.encode64(file.read)

			b64
		rescue
		 	"failed"

		ensure
		 	file.close unless file.nil?
		end
	end
	
end