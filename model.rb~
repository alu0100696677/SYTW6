class ShortenedUrl
  include DataMapper::Resource

  property :id, Serial
  property :url, Text
  property :to, Text
  property :id_usu, Text

  has n, :visits
end

class Visit
  include DataMapper::Resource

  property :id, Serial
  property :created_at, DateTime
  property :ip, IPAddress
  property :country, String

  belongs_to :shortenedurl
end
