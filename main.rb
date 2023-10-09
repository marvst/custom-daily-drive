require 'httparty'
require 'base64'
require 'dotenv'
require 'yaml'

Dotenv.load

CLIENT_ID = ENV["CLIENT_ID"]
CLIENT_SECRET = ENV["CLIENT_SECRET"]
CALLBACK_URI = ENV["CALLBACK_URI"]

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

def main()
    config = YAML.load_file('config.yml')

    access_token = generate_access_token_from_refresh_token(config[:refresh_token])

    tracks = get_user_top_tracks(access_token)
    todays_episodes = get_last_episodes_from_user_shows(access_token, config[:shows]).select do |episode|
        release_date =  Date.parse(episode['release_date'])

        release_date == Date.today ||
        [0, 6].include?(release_date.wday)
    end

    updated = update_daily_drive_playlist(access_token, config[:playlist], tracks, todays_episodes)

    if updated
        puts "All good :)" 
        
        return
    else
        puts "No good :("
        
        return
    end
end

main()