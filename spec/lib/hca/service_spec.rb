# frozen_string_literal: true
require 'rails_helper'
require 'hca/service'

describe HCA::Service do
  let(:cert) { instance_double('OpenSSL::X509::Certificate') }
  let(:key) { instance_double('OpenSSL::PKey::RSA') }
  let(:store) { instance_double('OpenSSL::X509::Store') }

  describe '#submit_form' do
    context 'conformance tests', run_at: '2016-12-12' do
      root = Rails.root.join('spec', 'fixtures', 'hca', 'conformance')
      Dir[File.join(root, '*.json')].map { |f| File.basename(f, '.json') }.each do |form|
        it "properly formats #{form} for transmission" do
          json = JSON.load(root.join("#{form}.json"))
          xml = File.read(root.join("#{form}.xml"))
          expect(subject).to receive(:post_submission) do |arg|
            submission = arg.body
            pretty_printed = Ox.dump(Ox.parse(submission).locate('soap:Envelope/soap:Body/ns1:submitFormRequest').first)
            expect(xml).to eq(pretty_printed[1..-1])
          end

          subject.submit_form(json)
        end
      end
    end
  end

  describe '#health_check' do
    context 'with a valid request' do
      it 'returns the id and a timestamp' do
        VCR.use_cassette('hca/health_check', match_requests_on: [:body]) do
          response = subject.health_check
          expect(response).to eq(
            id: ::HCA::Configuration::HEALTH_CHECK_ID,
            timestamp: '2016-12-12T08:06:08.423-06:00'
          )
        end
      end
    end

    context 'with a valid request' do
      it 'raises an exception' do
        VCR.use_cassette('hca/health_check_downtime', match_requests_on: [:body]) do
          expect { subject.health_check }.to raise_error(SOAP::Errors::HTTPError)
        end
      end
    end
  end

  describe '.options' do
    before(:each) do
      stub_const('HCA::Configuration::SSL_CERT', cert)
      stub_const('HCA::Configuration::SSL_KEY', key)
      stub_const('HCA::Configuration::CERT_STORE', store)
      stub_const('HCA::Configuration::ENDPOINT', nil)
    end

    context 'when there are no SSL options' do
      it 'should only return the wsdl' do
        stub_const('HCA::Configuration::SSL_CERT', nil)
        stub_const('HCA::Configuration::SSL_KEY', nil)
        expect(HCA::Configuration.instance.ssl_options).to eq(
          verify: true,
          cert_store: store
        )
      end
    end
    context 'when there are SSL options' do
      it 'should return the wsdl, cert and key paths' do
        expect(HCA::Configuration.instance.ssl_options).to eq(
          verify: true,
          cert_store: store,
          client_cert: cert,
          client_key: key
        )
      end
    end
  end
end
