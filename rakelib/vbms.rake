# frozen_string_literal: true

namespace :vbms do
  desc 'connection testing'
  task test_connection: :environment do
    # This is reliant on the following Env vars being set
    # CONNECT_VBMS_BASE_URL
    # CONNECT_VBMS_CACERT
    # CONNECT_VBMS_CERT
    # CONNECT_VBMS_CLIENT_KEYFILE
    # CONNECT_VBMS_KEYPASS
    # CONNECT_VBMS_SAML
    # CONNECT_VBMS_SERVER_CERT
    # CONNECT_VBMS_SHA256
    # ONNECT_VBMS_URL
    # CONNECT_VBMS_ENV_DIR
    require 'vbms'
    client = VBMS::Client.from_env_vars
    puts client.inspect
    request = VBMS::Requests::FindDocumentSeriesReference.new('796104437')
    result = client.send_request(request)
    puts result.inspect
  end
end
