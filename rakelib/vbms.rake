# frozen_string_literal: true

namespace :vbms do
  desc 'connection testing'
  task test_connection: :environment do
    client = VBMS::Client.new(
      Settings.vbms_url,
      '<path to key store>',
      Settings.vbms.saml_token_path,
      Settings.vmbs.key_path,
      Settings.vmbs.key_password,
      '<path to CA certificate, or nil>',
      '<path to client certificate, or nil>'
    )
    puts client.inspect
  end
end
