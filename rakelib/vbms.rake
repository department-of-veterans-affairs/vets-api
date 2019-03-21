# frozen_string_literal: true

namespace :vbms do

  desc 'connection testing'
  task test_connection: :environment do
    client = VBMS::Client.new(
        '<endpoint URL for the environment you want to access>',
        '<path to key store>',
        '<path to SAML XML token>',
        '<path to key, or nil>',
        '<password for key store>',
        '<path to CA certificate, or nil>',
        '<path to client certificate, or nil>',
    )
    puts client.inspect
  end
end
