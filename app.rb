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
  @list = ShortenedUrl.all(:order => [ :id.asc ], :limit => 20, :id_usu => " ") 
  # in SQL => SELECT * FROM "ShortenedUrl" ORDER BY "id" ASC
  haml :index

end


get '/auth/:name/callback' do
	session[:auth] = @auth = request.env['omniauth.auth']
	session[:email] = @auth['info'].email

	if session[:auth] then #@auth
		begin
			puts "inside get '/': #{params}"
			@list = ShortenedUrl.all(:order => [ :id.asc ], :limit => 20, :id_usu => session[:email])
			# in SQL => SELECT * FROM "ShortenedUrl" ORDER BY "id" ASC
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


post '/' do
  puts "inside post '/': #{params}"
  uri = URI::parse(params[:url])
  if uri.is_a? URI::HTTP or uri.is_a? URI::HTTPS then
    begin
        #@short_url = ShortenedUrl.first_or_create(:url => params[:url])
    	if params[:to] == " "
    		@short_url = ShortenedUrl.first_or_create(:url => params[:url], :id_usu => session[:email])
    	else
    		@short_url = ShortenedUrl.first_or_create(:url => params[:url], :to => params[:to], :id_usu => session[:email])
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


get '/:shortened' do
  puts "inside get '/:shortened': #{params}"
  short_url = ShortenedUrl.first(:id => params[:shortened].to_i(Base))

  to_url = ShortenedUrl.first(:to => params[:shortened])

  # HTTP status codes that start with 3 (such as 301, 302) tell the
  # browser to go look for that resource in another location. This is
  # used in the case where a web page has moved to another location or
  # is no longer at the original location. The two most commonly used
  # redirection status codes are 301 Move Permanently and 302 Found.

  #redirect short_url.url, 301
  
  if to_url
	redirect to_url.url, 301
  else
	redirect short_url.url, 301
  end

end

error do erb :not_found end
