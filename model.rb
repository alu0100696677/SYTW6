require 'dm-core'
require 'dm-migrations'
require 'restclient'
require 'xmlsimple'
require 'dm-timestamps'

class Shortenedurl
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
  property :city, String

  belongs_to :shortenedurl

  def self.date_with(identifier)
    repository(:default).adapter.select("SELECT date(created_at) AS date , count(*) AS count FROM visits WHERE shortenedurl_id = '#{identifier}' GROUP BY date(created_at)")
  end

  def self.count_by_country_with(identifier)
    repository(:default).adapter.select("SELECT country, count(*) AS count FROM visits WHERE shortenedurl_id = '#{identifier}' GROUP BY country")
  end

end
