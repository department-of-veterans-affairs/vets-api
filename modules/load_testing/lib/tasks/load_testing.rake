namespace :load_testing do
  desc 'Verify load testing setup'
  task verify: :environment do
    client = SignIn::ClientConfig.find_by(client_id: 'load_test_client')
    if client.nil?
      puts "Error: Load testing client not found"
      puts "Running migration..."
      Rake::Task['db:migrate'].invoke
    else
      puts "Load testing client configuration found:"
      puts JSON.pretty_generate(client.as_json)
    end
  end
end 