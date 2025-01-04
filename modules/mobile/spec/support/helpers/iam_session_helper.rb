# frozen_string_literal: true

module IAMSessionHelper
  DEFAULT_ACCESS_TOKEN = 'ypXeAwQedpmAy5xFD2u5'
  OPENSSL_X509_CERTIFICATE = 'OpenSSL::X509::Certificate'
  OPENSSL_PKEY_RSA = 'OpenSSL::PKey::RSA'

  def access_token
    DEFAULT_ACCESS_TOKEN
  end

  def iam_headers(additional_headers = nil)
    headers = {
      'Authorization' => "Bearer #{access_token}",
      'X-Key-Inflection' => 'camel'
    }
    headers.merge!(additional_headers) if additional_headers
    headers
  end

  def iam_headers_no_camel(additional_headers = nil)
    headers = { 'Authorization' => "Bearer #{access_token}" }
    headers.merge!(additional_headers) if additional_headers
    headers
  end

  def stub_iam_certs
    config = IAMSSOeOAuth::Configuration.instance
    allow(config).to receive_messages(ssl_cert: OpenStruct.new(to_der: 'dummy_cert_data'),
                                      ssl_key: OpenStruct.new(to_der: 'dummy_key_data'))
  end

  def iam_sign_in(iam_user = FactoryBot.build(:iam_user), access_token = nil)
    token = access_token || DEFAULT_ACCESS_TOKEN
    IAMUser.create(iam_user)
    IAMSession.create(token:, uuid: iam_user.identity.uuid)
  end
end

RSpec.configure do |config|
  config.include IAMSessionHelper

  config.before :each, type: :request do
    Flipper.enable('va_online_scheduling')
    stub_iam_certs
  end

  config.before :each, type: :controller do
    Flipper.enable('va_online_scheduling')
    stub_iam_certs
  end
end
