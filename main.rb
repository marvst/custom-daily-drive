require 'sinatra'
require 'httparty'
require 'base64'
require 'dotenv'
require 'yaml'

# TODO
# 1. Create migrations and integrate https://cloud.google.com/ruby/docs/reference/google-cloud-firestore/latest/AUTHENTICATION
# 2. Start saving to the database on /callback https://cloud.google.com/ruby/docs/reference/google-cloud-firestore/latest#adding-data
# 3. Start reading from the database on /generate https://cloud.google.com/ruby/docs/reference/google-cloud-firestore/latest#retrieving-collection-references
# 4. Make /generate to run for each entry (loop)

Dotenv.load

CLIENT_ID = ENV["CLIENT_ID"]
CLIENT_SECRET = ENV["CLIENT_SECRET"]
CALLBACK_URI = ENV["CALLBACK_URI"]

def get_user_top_tracks(access_token)
    response = HTTParty.get(
        'https://api.spotify.com/v1/me/top/tracks',
        headers: {
            "Authorization" => "Bearer #{access_token}"
        },
        query: {
            time_range: "medium_term",
            limit: 20,
            offset: rand(10)
        }
    ).parsed_response

    response['items']
end

def update_daily_drive_playlist(access_token, playlist_id, tracks, episodes)
    tracks_and_episodes = []

    if episodes.empty?
        tracks_and_episodes = tracks
    else
        sliced_tracks = tracks.each_slice(tracks.length / episodes.length).to_a
    
        counter = 0
        episodes.each do |episode|
            tracks_and_episodes.push([episode] + sliced_tracks[counter])
    
            counter += 1
        end
    end

    uris = tracks_and_episodes.flatten.map { |item| item['uri'] }

    response = HTTParty.put(
        "https://api.spotify.com/v1/playlists/#{playlist_id}/tracks",
        headers: {
            "Authorization" => "Bearer #{access_token}"
        },
        query: {
            uris: uris.join(',')
        }
    ).parsed_response

    response 
end

def get_last_episodes_from_user_shows(access_token, shows)
    last_episodes = []

    shows.each do |show_id|
        response = HTTParty.get(
            "https://api.spotify.com/v1/shows/#{show_id}/episodes",
            headers: {
                "Authorization" => "Bearer #{access_token}"
            },
            query: {
                market: 'US',
                limit: 1
            }
        ).parsed_response

        last_episodes.push(response['items'][0])
    end

    last_episodes
end

def generate_access_token_from_refresh_token(refresh_token)
    token = Base64.strict_encode64("#{CLIENT_ID}:#{CLIENT_SECRET}")

    response = HTTParty.post(
        'https://accounts.spotify.com/api/token',
        query: {
            grant_type: "refresh_token",
            refresh_token: refresh_token,
            redirect_uri: CALLBACK_URI
        },
        headers: {
            "Authorization" => "Basic #{token}",
            "Content-Type" => "application/x-www-form-urlencoded"
        }
    ).parsed_response

    response['access_token']
end

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

get '/generate' do
    config = YAML.load_file('config.yml')

    access_token = generate_access_token_from_refresh_token(config[:refresh_token])

    tracks = get_user_top_tracks(access_token)
    todays_episodes = get_last_episodes_from_user_shows(access_token, config[:shows]).select do |episode|
        release_date =  Date.parse(episode['release_date'])

        release_date == Date.today ||
        [0, 6].include?(release_date.wday) && Date.today.wday == 1
    end

    updated = update_daily_drive_playlist(access_token, config[:playlist], tracks, todays_episodes)

    if updated
        return "All good :)" 
    else
        return "No good :("
    end
end