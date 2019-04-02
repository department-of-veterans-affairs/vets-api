# frozen_string_literal: true

namespace :vbms do
  desc 'connection testing'
  task test_connection: :environment do
    require 'vbms'
    client = VBMS::Client.from_env_vars
    puts client.inspect
    request = VBMS::Requests::FindDocumentSeriesReference.new('796104437')
    result = client.send_request(request)
    puts result.inspect
  end
end
