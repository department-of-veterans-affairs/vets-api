LoadTesting.configure do |config|
  config.allowed_teams = ['identity']
  config.max_concurrent_users = 1000
  config.token_lifetime = 30.minutes
  config.api_base_url = 'http://localhost:3000'
end 