# frozen_string_literal: true

require 'rails_helper'
require 'hca/service'

describe HCA::Service do
  include SchemaMatchers

  let(:service) { described_class.new }
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
  let(:current_user) { FactoryBot.build(:user, :loa3, icn: nil) }

  describe '#submit_form' do
    it 'increments statsd' do
      expect(StatsD).to receive(:increment).with('api.1010ez.submit_form.fail',
                                                 tags: ['error:VCRErrorsUnhandledHTTPRequestError'])
      expect(StatsD).to receive(:increment).with('api.1010ez.submit_form.total')

      expect do
        service.submit_form(build(:health_care_application).parsed_form)
      end.to raise_error(StandardError)

      allow_any_instance_of(described_class).to receive(:perform).and_return(response)
      expect(StatsD).not_to receive(:increment).with('api.1010ez.submit_form.fail')
      expect(StatsD).to receive(:increment).with('api.1010ez.submit_form.total')

      service.submit_form(build(:health_care_application).parsed_form)
    end

    context 'conformance tests', run_at: '2016-12-12' do
      root = Rails.root.join('spec', 'fixtures', 'hca', 'conformance')
      Dir[File.join(root, '*.json')].map { |f| File.basename(f, '.json') }.each do |form|
        it "properly formats #{form} for transmission" do
          allow_any_instance_of(MPIData).to receive(:icn).and_return('1000123456V123456')
          service =
            if form.match?(/authenticated/)
              described_class.new(
                HealthCareApplication.get_user_identifier(current_user)
              )
            else
              described_class.new
            end

          json = JSON.parse(File.open(root.join("#{form}.json")).read)
          expect(json).to match_vets_schema('10-10EZ')
          xml = File.read(root.join("#{form}.xml"))
          expect(service).to receive(:perform) do |_verb, _, body|
            submission = body
            pretty_printed = Ox.dump(Ox.parse(submission).locate('soap:Envelope/soap:Body/ns1:submitFormRequest').first)
            expect(pretty_printed[1..]).to eq(xml)
          end.and_return(response)

          service.submit_form(json)
        end
      end
    end

    context 'submitting with attachment' do
      xit 'works', run_at: 'Fri, 11 Jan 2019 04:56:26 GMT' do
        VCR.use_cassette(
          'hca/submit_with_attachment',
          VCR::MATCH_EVERYTHING.merge(erb: true)
        ) do
          result = HCA::Service.new.submit_form(create(:hca_app_with_attachment).parsed_form)
          expect(result[:success]).to eq(true)
        end
      end

      context 'with a non-pdf attachment' do
        xit 'works', run_at: 'Fri, 11 Jan 2019 04:56:26 GMT' do
          hca_attachment = build(:hca_attachment)
          hca_attachment.set_file_data!(
            Rack::Test::UploadedFile.new(
              'spec/fixtures/files/sm_file1.jpg',
              'image/jpeg'
            )
          )
          hca_attachment.save!

          health_care_application = build(:health_care_application)
          form = health_care_application.parsed_form
          form['attachments'] = [
            {
              'confirmationCode' => hca_attachment.guid,
              'dd214' => true
            }
          ]
          health_care_application.form = form.to_json
          health_care_application.send(:remove_instance_variable, :@parsed_form)
          health_care_application.save!

          VCR.use_cassette(
            'hca/submit_with_attachment_jpg',
            VCR::MATCH_EVERYTHING.merge(erb: true)
          ) do
            result = HCA::Service.new.submit_form(health_care_application.parsed_form)
            expect(result[:success]).to eq(true)
          end
        end
      end
    end

    context 'receives a 503 response' do
      it 'rescues and raises GatewayTimeout exception' do
        expect(service).to receive(:connection).and_return(
          Faraday.new do |conn|
            conn.builder.handlers = service.send(:connection).builder.handlers.reject do |x|
              x.inspect == 'Faraday::Adapter::NetHttp'
            end
            conn.adapter :test do |stub|
              stub.post('/') { [503, { body: 'it took too long!' }, 'timeout'] }
            end
          end
        )
        expect { service.send(:request, :post, '', OpenStruct.new(body: nil)) }.to raise_error(
          Common::Exceptions::GatewayTimeout
        )
      end
    end
  end

  describe '#health_check' do
    context 'with a valid request' do
      it 'increments statsd' do
        VCR.use_cassette('hca/health_check', match_requests_on: [:body]) do
          expect do
            subject.health_check
          end.to trigger_statsd_increment('api.1010ez.health_check.total')
        end
      end

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

    context 'with an invalid request' do
      it 'raises an exception' do
        VCR.use_cassette('hca/health_check_downtime', match_requests_on: [:body]) do
          expect { subject.health_check }.to raise_error(Common::Client::Errors::HTTPError)
        end
      end
    end
  end
end
