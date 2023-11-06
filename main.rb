require_relative 'helpers.rb'

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
    puts "All good :)" 
else
    puts "No good :("
end