# frozen_string_literal: true

namespace :bgs_test do
  task connection: :environment do
    BGS::Services.new(
      env: 'development',
      client_ip: '127.0.0.1',
      client_station_id: '281',
      client_username: 'VAgovAPI',
      application: 'VAgovAPI'
    )
  end
end
