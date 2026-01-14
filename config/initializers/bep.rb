# frozen_string_literal: true

require 'socket'

Rails.application.reloader.to_prepare do
  # OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
  BGS.configure do |config|
    config.application = Settings.bep.application
    config.client_ip = Socket.ip_address_list.detect(&:ipv4_private?).ip_address
    config.client_station_id = Settings.bep.client_station_id
    config.client_username = Settings.bep.client_username
    config.env = Settings.bep.env
    config.mock_response_location = Settings.bep.mock_response_location
    config.mock_responses = Settings.bep.mock_responses
    config.external_uid = Settings.bep.external_uid
    config.external_key = Settings.bep.external_key
    config.forward_proxy_url = Settings.bep.url
    config.ssl_verify_mode = Settings.bep.ssl_verify_mode
  end
end
