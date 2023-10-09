require 'sinatra'
require 'httparty'
require 'base64'
require 'dotenv'
require 'yaml'

Dotenv.load

CLIENT_ID = ENV["CLIENT_ID"]
CLIENT_SECRET = ENV["CLIENT_SECRET"]
CALLBACK_URI = ENV["CALLBACK_URI"]

def generate_access_tokens(code)    
    token = Base64.strict_encode64("#{CLIENT_ID}:#{CLIENT_SECRET}")

    response = HTTParty.post(
        'https://accounts.spotify.com/api/token',
        query: {
            grant_type: "authorization_code",
            code: code,
            redirect_uri: CALLBACK_URI
        },
        headers: {
            "Authorization" => "Basic #{token}",
            "Content-Type" => "application/x-www-form-urlencoded"
        }
    ).parsed_response

    response
end

get '/' do
    erb :login
end

get '/auth' do
    config = YAML.load_file('config.yml')

    if config['refresh_token'].nil?
        redirect "https://accounts.spotify.com/authorize?client_id=#{CLIENT_ID}&response_type=code&redirect_uri=#{CALLBACK_URI}&scope=user-top-read playlist-modify-private"
    end

    "You already authorized us :)"
end

get '/callback' do
    code = params['code']

    if code.nil?
        return "Authorization didn't work because we didn't receive your code back from Spotify :("
    end

    config = YAML.load_file('config.yml')

    if !config['refresh_token'].nil?
        return "You already authorize us :)"
    end

    access_tokens = generate_access_tokens(code)

    new_config = {
        refresh_token: access_tokens['refresh_token'],
        shows: config['shows'],
        playlist: config['playlist']
    }

    File.open('config.yml', 'w') { |file| file.write(new_config.to_yaml) }

    "Done"
end