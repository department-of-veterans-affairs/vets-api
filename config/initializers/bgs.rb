# frozen_string_literal: true

require 'socket'

Rails.application.reloader.to_prepare do
  # OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
  BGS.configure do |config|
    config.application = Settings.bgs.application
    config.client_ip = Socket.ip_address_list.detect(&:ipv4_private?).ip_address
    config.client_station_id = Settings.bgs.client_station_id
    config.client_username = Settings.bgs.client_username
    config.env = Settings.bgs.env
    config.mock_response_location = Settings.bgs.mock_response_location
    config.mock_responses = Settings.bgs.mock_responses
    config.external_uid = Settings.bgs.external_uid
    config.external_key = Settings.bgs.external_key
    config.forward_proxy_url = Settings.bgs.url
    config.ssl_verify_mode = Settings.bgs.ssl_verify_mode
  end
end
