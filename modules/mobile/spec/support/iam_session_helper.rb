# frozen_string_literal: true

module IAMSessionHelper
  DEFAULT_ACCESS_TOKEN = 'ypXeAwQedpmAy5xFD2u5'

  def access_token
    DEFAULT_ACCESS_TOKEN
  end

  def stub_certs
    allow(IAMSSOeOAuth::Configuration.instance).to receive(:ssl_cert)
      .and_return(instance_double('OpenSSL::X509::Certificate'))
    allow(IAMSSOeOAuth::Configuration.instance).to receive(:ssl_key)
      .and_return(instance_double('OpenSSL::PKey::RSA'))
  end

  def sign_in(iam_user = FactoryBot.build(:iam_user), access_token = nil)
    token = access_token || DEFAULT_ACCESS_TOKEN
    IAMUser.create(iam_user)
    IAMSession.create(token: token, uuid: iam_user.identity.uuid)
  end
end
