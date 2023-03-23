# frozen_string_literal: true

module IAMSessionHelper
  DEFAULT_ACCESS_TOKEN = 'ypXeAwQedpmAy5xFD2u5'

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
    allow(IAMSSOeOAuth::Configuration.instance).to receive(:ssl_cert)
      .and_return(instance_double('OpenSSL::X509::Certificate'))
    allow(IAMSSOeOAuth::Configuration.instance).to receive(:ssl_key)
      .and_return(instance_double('OpenSSL::PKey::RSA'))
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
