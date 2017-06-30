require 'yaml'
require 'pry'

desc 'To users on dev suitable for testing'
task :appeals do
  mock_mvi = YAML.load_file('config/mvi_schema/mock_mvi_responses.yml')
  client = AppealsStatus::Service.new
  mock_mvi['find_candidate'].values.each do |mock_user|
    begin
      user = OpenStruct.new(mock_user)
      response = client.get_appeals(user)
      puts "Found #{user.ssn}"
    rescue Common::Exceptions::BackendServiceException => e
      #puts e.original_body['errors'].first['detail']
    end
  end
end
