# frozen_string_literal: true

require 'socket'

ip = Socket.ip_address_list.detect(&:ipv4_private?)

LighthouseBGS.configure do |config|
  config.application = Settings.bgs.application
  config.client_ip = ip.ip_address
  config.client_station_id = Settings.bgs.client_station_id
  config.client_username = Settings.bgs.client_username
  config.env = Rails.env.to_s
  config.mock_response_location = Settings.bgs.mock_response_location
  config.mock_responses = Settings.bgs.mock_responses
end
