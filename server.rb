require 'sinatra'
require_relative 'helpers.rb'

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