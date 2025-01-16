# frozen_string_literal: true

require 'rails_helper'
require 'iam_ssoe_oauth/configuration'

describe 'IAMSSOeOAuth::Configuration' do
  subject { IAMSSOeOAuth::Configuration.instance }

  before do
    allow(IAMSSOeOAuth::Configuration.instance).to receive_messages(
      ssl_cert: instance_double(OpenSSL::X509::Certificate), ssl_key: instance_double(OpenSSL::PKey::RSA)
    )
  end

  describe '#base_path' do
    it 'returns the value from the env settings' do
      expect(subject.base_path).to eq('https://int.fed.eauth.va.gov:444')
    end
  end

  describe '#service_name' do
    it 'overrides service_name with a unique name' do
      expect(subject.service_name).to eq('IAMSSOeOAuth')
    end
  end

  describe '#connection' do
    it 'returns a faraday connection' do
      expect(subject.connection).to be_a(Faraday::Connection)
    end
  end
end
