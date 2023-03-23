# frozen_string_literal: true

require 'vbms'
namespace :vbms do
  desc 'connection testing'
  task initialize_upload: :environment do
    # This is reliant on the following Env vars being set via the settings file
    # CONNECT_VBMS_BASE_URL
    # CONNECT_VBMS_CACERT
    # CONNECT_VBMS_CERT
    # CONNECT_VBMS_CLIENT_KEYFILE
    # CONNECT_VBMS_KEYPASS
    # CONNECT_VBMS_SAML
    # CONNECT_VBMS_SERVER_CERT
    # CONNECT_VBMS_SHA256
    # CONNECT_VBMS_URL
    # CONNECT_VBMS_ENV_DIR
    # ENV['CONNECT_VBMS_BASE_URL'] = Settings.vbms.vbms_base_url
    # ENV['CONNECT_VBMS_CACERT'] = Settings.vbms.vbms_ca_cert
    # ENV['CONNECT_VBMS_CERT'] = Settings.vbms.cert
    # ENV['CONNECT_VBMS_CLIENT_KEYFILE'] = Settings.vbms.client_keyfile
    # ENV['CONNECT_VBMS_KEYPASS'] = Settings.vbms.keypass
    # ENV['CONNECT_VBMS_SAML'] = Settings.vbms.saml
    # ENV['CONNECT_VBMS_SERVER_CERT'] = Settings.vbms.server_cert
    # ENV['CONNECT_VBMS_SHA256'] = Setting.vbms.
    # ENV['CONNECT_VBMS_URL'] = Setting.vbms.
    # ENV['CONNECT_VBMS_ENV_DIR'] = Settings.vbms.environment
    client = VBMS::Client.from_env_vars
    file_name = 'VBA-21-22A-ARE.pdf'
    content_hash = Digest::SHA1.hexdigest(File.read(file_name))
    filename = SecureRandom.uuid + File.basename(file_name)
    veteran = OpenStruct.new(filenumber: '796378881')
    document = OpenStruct.new(source: 'BVA', document_type: '295')

    request = VBMS::Requests::InitializeUpload.new(
      content_hash:,
      filename:,
      file_number: veteran.filenumber,
      va_receive_date: Time.zone.now,
      doc_type: document.document_type,
      source: document.source,
      subject: document.document_type,
      new_mail: true
    )
    result = client.send_request(request)
    puts result.inspect
    puts result.class
    puts result.upload_token
  end

  task upload_document: :environment do
    client = VBMS::Client.from_env_vars
    filepath = 'VBA-21-22A-ARE.pdf'
    request = VBMS::Requests::UploadDocument.new(
      upload_token: '{9532DD12-92D0-4BC7-BDAB-2C7D59AF4D70}',
      filepath:
    )
    result = client.send_request(request)
    puts result.inspect
  end
end
