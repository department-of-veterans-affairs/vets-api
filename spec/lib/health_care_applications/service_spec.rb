# frozen_string_literal: true
require 'rails_helper'
require 'health_care_applications/service'

describe HealthCareApplications::Service do
  let(:cert) { instance_double('OpenSSL::X509::Certificate') }
  let(:key) { instance_double('OpenSSL::PKey::RSA') }
  let(:store) { instance_double('OpenSSL::X509::Store') }

  describe '#health_check' do
    context 'with a valid request' do
      it 'returns the id and a timestamp' do
        VCR.use_cassette('health_care_applications/health_check', match_requests_on: [:body]) do
          response = subject.health_check
          expect(response).to eq(
            id: ::HealthCareApplications::Settings::HEALTH_CHECK_ID,
            timestamp: '2016-12-12T08:06:08.423-06:00'
          )
        end
      end
    end

    context 'with a valid request' do
      it 'raises an exception' do
        VCR.use_cassette('health_care_applications/health_check_downtime', match_requests_on: [:body]) do
          expect { subject.health_check }.to raise_error(SOAP::Errors::HTTPError)
        end
      end
    end
  end

  describe '.options' do
    before(:each) do
      stub_const('HealthCareApplications::Settings::SSL_CERT', cert)
      stub_const('HealthCareApplications::Settings::SSL_KEY', key)
      stub_const('HealthCareApplications::Settings::CERT_STORE', store)
      stub_const('HealthCareApplications::Settings::ENDPOINT', nil)
    end

    context 'when there are no SSL options' do
      it 'should only return the wsdl' do
        stub_const('HealthCareApplications::Settings::SSL_CERT', nil)
        stub_const('HealthCareApplications::Settings::SSL_KEY', nil)
        expect(HealthCareApplications::Service.options).to eq(
          url: nil,
          ssl: {
            verify: true,
            cert_store: store
          }
        )
      end
    end
    context 'when there are SSL options' do
      it 'should return the wsdl, cert and key paths' do
        expect(HealthCareApplications::Service.options).to eq(
          url: nil,
          ssl: {
            verify: true,
            cert_store: store,
            client_cert: cert,
            client_key: key
          }
        )
      end
    end
  end
end
