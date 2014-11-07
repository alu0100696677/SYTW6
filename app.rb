#!/usr/bin/env ruby
require 'rubygems'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'haml'
require 'uri'
require 'data_mapper'
require 'omniauth-oauth2'
require 'omniauth-google-oauth2'
require 'pry'
require 'erubis'
require 'chartkick'

require 'dm-core'
require 'dm-timestamps'
require 'dm-types'
require 'restclient'
require 'xmlsimple'

use OmniAuth::Builder do
  config = YAML.load_file 'config/config.yml'
  provider :google_oauth2, config['identifier'], config['secret']
end

enable :sessions
set :sessions_secret, '*&(^#234a)'

disable :show_exceptions
disable :raise_errors

configure :development do
	DataMapper.setup( :default, ENV['DATABASE_URL'] || 
                          "sqlite3://#{Dir.pwd}/my_shortened_urls.db" )
end

configure :production do
	DataMapper.setup(:default, ENV['DATABASE_URL'])
end

DataMapper::Logger.new($stdout, :debug)
DataMapper::Model.raise_on_save_failure = true 

require_relative 'model'

DataMapper.finalize

#DataMapper.auto_migrate!
DataMapper.auto_upgrade!

not_found do
	status 404
	erb :not_found
end

Base = 36


get '/' do
  puts "inside get '/': #{[params]}"
  session[:email] = " "
  @list = Shortenedurl.all(:order => [ :id.asc ], :limit => 20, :id_usu => " ") 
  # in SQL => SELECT * FROM "Shortenedurl" ORDER BY "id" ASC
  haml :index
end


get '/auth/:name/callback' do
	session[:auth] = @auth = request.env['omniauth.auth']
	session[:email] = @auth['info'].email

	if session[:auth] then #@auth
		begin
			puts "inside get '/': #{params}"
			@list = Shortenedurl.all(:order => [ :id.asc ], :limit => 20, :id_usu => session[:email])
			# in SQL => SELECT * FROM "Shortenedurl" ORDER BY "id" ASC
			haml :index
		end
	else
		redirect '/auth/failure'
	end
		
end

get '/auth/failure' do
  session.clear
  redirect '/'
end

get '/stadistic' do
  get_ip()
  #haml :stadistic, :layout =>
end

def get_ip()
  puts "request.ip = #{request.ip}"
end

post '/' do
  puts "inside post '/': #{params}"
  uri = URI::parse(params[:url])
  if uri.is_a? URI::HTTP or uri.is_a? URI::HTTPS then
    begin
        #@short_url = Shortenedurl.first_or_create(:url => params[:url])
    	if params[:to] == " "
    		@short_url = Shortenedurl.first_or_create(:url => params[:url], :id_usu => session[:email])
    	else
    		@short_url = Shortenedurl.first_or_create(:url => params[:url], :to => params[:to], :id_usu => session[:email])
    	end
      rescue Exception => e
        puts "EXCEPTION!!!!!!!!!!!!!!!!!!!"
        pp @short_url
        puts e.message
    end
  else
    logger.info "Error! <#{params[:url]}> is not a valid URL"
  end
  redirect '/'
end

#Visitar url corta sin que case con todo
get '/visita/:shortened' do
  puts "inside get '/visita/:shortened': #{params}"
  #short_url = Shortenedurl.first(:id => params[:shortened].to_i(Base))
  #to_url = Shortenedurl.first(:to => params[:shortened])

  url = Shortenedurl.first(:to => params[:shortened])
  short = (url != nil) ? url : Shortenedurl.first(:id => params[:shortened].to_i(Base))

  #Datos que vamos a guardar en la tabla visits
  ip = get_remote_ip(env)
  xml = RestClient.get "ip-api.com/xml/95.127.58.243"#{ip}"
  data = XmlSimple.xml_in(xml.to_s)
  info = {"country"=>data["country"][0].to_s,"city"=>data["city"][0].to_s}
  
  #Guardar los datos
  Visit.create(:ip => ip, :country => info['country'], :city => info['city'], :shortenedurl => short, :created_at => Time.now)

  redirect short.url, 301

#  if to_url
#	redirect to_url.url, 301
#  else
#	redirect short_url.url, 301
#  end

end

error do erb :not_found end

def get_remote_ip(env)
  puts "request.url = #{request.url}"
  puts "request.ip = #{request.ip}"

  if addr = env['HTTP_X_FORWARDED_FOR']
    puts "env['HTTP_X_FORWARDED_FOR'] = #{addr}"
    addr.split('.').first.strip
  else
    puts "env['REMOTE_ADDR'] = #{env['REMOTE_ADDR']}"
    env['REMOTE_ADDR']
  end
end

get '/info/:short_url' do
  urlshort = Shortenedurl.first(:to => params[:short_url])
  @url = urlshort
  @visit_country = Visit.count_by_country_with(urlshort.id).to_s
  @visit_date = Visit.date_with(urlshort.id).to_s
  haml :info
  # En la vista
  # - @visit_country.each do |item|
  #   %p pais: #{item.country}
  #   %p visitas: #{item.count}
  # geo_chart #{@visit_country}
  # - @visit_date.each do |item|
  #   %p pais: #{item.date}
  #   %p visitas: #{item.count}
  # column_chart #{@visit_date}   
end

