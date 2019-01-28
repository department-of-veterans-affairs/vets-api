# frozen_string_literal: true

namespace :bgs_test do
  task connection: :environment do
    BGS::Services.new(
      env: 'development',
      client_ip: '127.0.0.1',
      client_station_id: '281',
      client_username: 'VAgovAPI',
      application: 'VAgovAPI',
      jumpbox_url: 'https://internal-dsva-vagov-dev-fwdproxy-1893365470.us-gov-west-1.elb.amazonaws.com:4447'
    )
  end
end
