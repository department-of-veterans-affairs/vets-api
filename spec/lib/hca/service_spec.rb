# frozen_string_literal: true

require 'rails_helper'
require 'hca/service'

describe HCA::Service do
  include SchemaMatchers

  let(:cert) { instance_double('OpenSSL::X509::Certificate') }
  let(:key) { instance_double('OpenSSL::PKey::RSA') }
  let(:store) { instance_double('OpenSSL::X509::Store') }
  let(:response) do
    double(body: Ox.parse(%(
    <?xml version='1.0' encoding='UTF-8'?>
    <S:Envelope>
      <S:Body>
        <submitFormResponse>
          <status>100</status>
          <formSubmissionId>40124668140</formSubmissionId>
          <message><type>Form successfully received for EE processing</type></message>
          <timeStamp>2016-05-25T04:59:39.345-05:00</timeStamp>
        </submitFormResponse>
      </S:Body>
    </S:Envelope>
     )))
  end
  let(:current_user) { FactoryBot.build(:user, :loa3) }

  describe '#submit_form' do
    context 'conformance tests', run_at: '2016-12-12' do
      root = Rails.root.join('spec', 'fixtures', 'hca', 'conformance')
      Dir[File.join(root, '*.json')].map { |f| File.basename(f, '.json') }.each do |form|
        it "properly formats #{form} for transmission" do
          allow_any_instance_of(Mvi).to receive(:icn).and_return('1000123456V123456')
          service = form =~ /authenticated/ ? described_class.new(current_user) : described_class.new
          json = JSON.load(root.join("#{form}.json"))
          expect(json).to match_vets_schema('10-10EZ')
          xml = File.read(root.join("#{form}.xml"))
          expect(service).to receive(:post_submission) do |arg|
            submission = arg.body
            pretty_printed = Ox.dump(Ox.parse(submission).locate('soap:Envelope/soap:Body/ns1:submitFormRequest').first)
            expect(pretty_printed[1..-1]).to eq(xml)
          end.and_return(response)

          service.submit_form(json)
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
            formSubmissionId: ::HCA::Configuration::HEALTH_CHECK_ID,
            timestamp: '2016-12-12T08:06:08.423-06:00'
          )
        end
      end
    end

    context 'with a valid request' do
      it 'raises an exception' do
        VCR.use_cassette('hca/health_check_downtime', match_requests_on: [:body]) do
          expect { subject.health_check }.to raise_error(Common::Client::Errors::HTTPError)
        end
      end
    end
  end

  describe '.options' do
    before(:each) do
      allow(HCA::Configuration.instance).to receive(:ssl_cert) { cert }
      allow(HCA::Configuration.instance).to receive(:ssl_key) { key }
      stub_const('HCA::Configuration::CERT_STORE', store)
      stub_const('HCA::Configuration::ENDPOINT', nil)
    end

    context 'when there are no SSL options' do
      it 'should only return the wsdl' do
        allow(HCA::Configuration.instance).to receive(:ssl_cert) { nil }
        allow(HCA::Configuration.instance).to receive(:ssl_key) { nil }
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
