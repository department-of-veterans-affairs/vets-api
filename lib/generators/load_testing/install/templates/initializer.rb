LoadTesting.configure do |config|
  # Configure which teams can access load testing
  config.allowed_teams = ['identity']

  # Maximum number of concurrent users allowed in a test
  config.max_concurrent_users = 1000

  # Token lifetime configuration
  config.token_lifetime = 30.minutes

  # Base URL for the API being tested
  config.api_base_url = ENV.fetch('LOAD_TEST_API_URL', 'http://localhost:3000')
end 