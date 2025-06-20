# frozen_string_literal: true

# rubocop:disable RSpec/ExampleWording

require 'rails_helper'
require 'hca/service'

DEFAULT_RUN_AT = 'Mon, 16 Jun 2025 17:21:51 GMT'

def with_run_at(custom_date = nil)
  { run_at: custom_date || DEFAULT_RUN_AT }
end

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
  let(:current_user) { build(:user, :loa3, icn: nil) }

  let(:vcr_options) { VCR::MATCH_EVERYTHING.merge(erb: true, record: :once) }

  describe '#submit_form' do
    before do
      allow(Rails.logger).to receive(:info)
    end

    context "when the 'va1010_forms_enrollment_system_service_enabled' flipper is enabled" do
      let(:enrollment_system_service) { instance_double(VA1010Forms::EnrollmentSystem::Service) }

      it "calls the new 'VA1010Forms::EnrollmentSystem::Service'" do
        allow(VA1010Forms::EnrollmentSystem::Service).to receive(:new).and_return(enrollment_system_service)

        form = get_fixture('hca/tera')

        expect(enrollment_system_service).to receive(:submit).with(form, '10-10EZ')

        service.submit_form(form)
      end

      it 'doesnt convert validation error to another error' do
        error = HCA::SOAPParser::ValidationError
        expect_any_instance_of(VA1010Forms::EnrollmentSystem::Service).to receive(:submit).and_raise(error)

        expect do
          service.submit_form(build(:health_care_application).parsed_form)
        end.to raise_error(error)
      end

      context 'logs submission payload size' do
        it 'works', with_run_at do
          VCR.use_cassette(
            'hca/short_form',
            vcr_options
          ) do
            result = HCA::Service.new.submit_form(get_fixture('hca/short_form'))
            expect(result[:success]).to be(true)
            expect(Rails.logger).to have_received(:info).with(
              'Payload for submitted 1010EZ: Body size of 5.16 KB with 0 attachment(s)'
            )
          end
        end
      end

      it 'increments statsd' do
        expect(StatsD).to receive(:increment).with(
          'api.1010ez.submit_form.fail', tags: ['error:VCRErrorsUnhandledHTTPRequestError']
        )
        expect(StatsD).to receive(:increment).with('api.1010ez.submit_form.total')

        expect do
          service.submit_form(build(:health_care_application).parsed_form)
        end.to raise_error(StandardError)

        allow_any_instance_of(VA1010Forms::EnrollmentSystem::Service).to receive(:perform).and_return(response)
        expect(StatsD).not_to receive(:increment).with('api.1010ez.submit_form.fail')
        expect(StatsD).to receive(:increment).with('api.1010ez.submit_form.total')

        service.submit_form(build(:health_care_application).parsed_form)
      end

      context 'with hasDemographicNoAnswer true' do
        it 'submits successfully to hca', with_run_at do
          VCR.use_cassette(
            'hca/demographic_no',
            vcr_options
          ) do
            form = get_fixture('hca/demographic_no')
            expect(HealthCareApplication.new(form: form.to_json).valid?).to be(true)

            result = HCA::Service.new.submit_form(form)
            expect(result[:success]).to be(true)
          end
        end
      end

      context 'with a medicare claim number' do
        it 'submits successfully to hca', with_run_at do
          VCR.use_cassette(
            'hca/medicare_claim_num',
            vcr_options
          ) do
            form = get_fixture('hca/medicare_claim_num')
            expect(HealthCareApplication.new(form: form.to_json).valid?).to be(true)

            result = HCA::Service.new.submit_form(form)
            expect(result[:success]).to be(true)
          end
        end
      end

      context 'submitting tera questions' do
        it 'works', with_run_at do
          VCR.use_cassette(
            'hca/tera',
            vcr_options
          ) do
            form = get_fixture('hca/tera')
            expect(HealthCareApplication.new(form: form.to_json).valid?).to be(true)
            result = HCA::Service.new.submit_form(form)
            expect(result[:success]).to be(true)
          end
        end
      end

      context 'submitting short form' do
        it 'works', with_run_at do
          VCR.use_cassette(
            'hca/short_form',
            vcr_options
          ) do
            result = HCA::Service.new.submit_form(get_fixture('hca/short_form'))
            expect(result[:success]).to be(true)
          end
        end

        it 'increments statsd' do
          allow(StatsD).to receive(:increment)

          expect(StatsD).to receive(:increment).with(
            'api.1010ez.submit_form_short_form.fail', tags: ['error:VCRErrorsUnhandledHTTPRequestError']
          )
          expect(StatsD).to receive(:increment).with('api.1010ez.submit_form_short_form.total')

          expect do
            HCA::Service.new.submit_form(get_fixture('hca/short_form'))
          end.to raise_error(StandardError)
        end
      end

      context 'submitting with attachment' do
        context "with the 'ezr_use_correct_format_for_file_uploads' flipper enabled" do
          before do
            allow(Flipper).to receive(:enabled?).and_call_original
            allow(Flipper).to receive(:enabled?).with(:ezr_use_correct_format_for_file_uploads).and_return(true)
          end

          it 'works', with_run_at do
            VCR.use_cassette(
              'hca/submit_with_attachment_formatted_correctly',
              vcr_options
            ) do
              result = HCA::Service.new.submit_form(create(:hca_app_with_attachment).parsed_form)
              expect(result[:success]).to be(true)
              expect(Rails.logger).to have_received(:info).with(
                'Payload for submitted 1010EZ: Body size of 16 KB with 2 attachment(s)'
              )
              expect(Rails.logger).to have_received(:info).with(
                'Attachment sizes in descending order: 1.8 KB, 1.8 KB'
              )
            end
          end

          context 'with a non-pdf attachment' do
            it 'works', with_run_at do
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
                'hca/submit_with_attachment_jpg_formatted_correctly',
                vcr_options
              ) do
                result = HCA::Service.new.submit_form(health_care_application.parsed_form)
                expect(result[:success]).to be(true)
              end
            end
          end
        end

        context "with the 'ezr_use_correct_format_for_file_uploads' flipper disabled" do
          before do
            allow(Flipper).to receive(:enabled?).and_call_original
            allow(Flipper).to receive(:enabled?).with(:ezr_use_correct_format_for_file_uploads).and_return(false)
          end

          it 'works', with_run_at do
            VCR.use_cassette(
              'hca/submit_with_attachment',
              vcr_options
            ) do
              result = HCA::Service.new.submit_form(create(:hca_app_with_attachment).parsed_form)
              expect(result[:success]).to be(true)
              expect(Rails.logger).to have_received(:info).with(
                'Payload for submitted 1010EZ: Body size of 16 KB with 2 attachment(s)'
              )
              expect(Rails.logger).to have_received(:info).with(
                'Attachment sizes in descending order: 1.8 KB, 1.8 KB'
              )
            end
          end

          context 'with a non-pdf attachment' do
            it 'works', with_run_at do
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
                vcr_options
              ) do
                result = HCA::Service.new.submit_form(health_care_application.parsed_form)
                expect(result[:success]).to be(true)
              end
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

    context "when the 'va1010_forms_enrollment_system_service_enabled' flipper is disabled" do
      before do
        Flipper.disable(:va1010_forms_enrollment_system_service_enabled)
      end

      it 'doesnt convert validation error to another error' do
        error = HCA::SOAPParser::ValidationError
        expect(service.send(:connection)).to receive(:post).and_raise(error)

        expect do
          service.submit_form(build(:health_care_application).parsed_form)
        end.to raise_error(error)
      end

      context 'logs submission payload size' do
        it 'works', with_run_at do
          VCR.use_cassette(
            'hca/short_form',
            vcr_options
          ) do
            result = HCA::Service.new.submit_form(get_fixture('hca/short_form'))
            expect(result[:success]).to be(true)
            expect(Rails.logger).to have_received(:info).with(
              'Payload for submitted 1010EZ: Body size of 5.16 KB with 0 attachment(s)'
            )
          end
        end
      end

      it 'increments statsd' do
        expect(StatsD).to receive(:increment).with(
          'api.1010ez.submit_form.fail', tags: ['error:VCRErrorsUnhandledHTTPRequestError']
        )
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

            json = JSON.parse(File.read(root.join("#{form}.json")))
            expect(json).to match_vets_schema('10-10EZ')
            xml = File.read(root.join("#{form}.xml"))
            expect(service).to receive(:perform) do |_verb, _, body|
              submission = body
              pretty_printed =
                Ox.dump(Ox.parse(submission).locate('soap:Envelope/soap:Body/ns1:submitFormRequest').first)
              expect(pretty_printed[1..]).to eq(xml)
            end.and_return(response)

            service.submit_form(json)
          end
        end
      end

      context 'with hasDemographicNoAnswer true' do
        it 'submits successfully to hca', with_run_at do
          VCR.use_cassette(
            'hca/demographic_no',
            vcr_options
          ) do
            form = get_fixture('hca/demographic_no')
            expect(HealthCareApplication.new(form: form.to_json).valid?).to be(true)

            result = HCA::Service.new.submit_form(form)
            expect(result[:success]).to be(true)
          end
        end
      end

      context 'with a medicare claim number' do
        it 'submits successfully to hca', with_run_at do
          VCR.use_cassette(
            'hca/medicare_claim_num',
            vcr_options
          ) do
            form = get_fixture('hca/medicare_claim_num')
            expect(HealthCareApplication.new(form: form.to_json).valid?).to be(true)

            result = HCA::Service.new.submit_form(form)
            expect(result[:success]).to be(true)
          end
        end
      end

      context 'submitting tera questions' do
        it 'works', with_run_at do
          VCR.use_cassette(
            'hca/tera',
            vcr_options
          ) do
            form = get_fixture('hca/tera')
            expect(HealthCareApplication.new(form: form.to_json).valid?).to be(true)
            result = HCA::Service.new.submit_form(form)
            expect(result[:success]).to be(true)
          end
        end
      end

      context 'submitting short form' do
        it 'works', with_run_at do
          VCR.use_cassette(
            'hca/short_form',
            vcr_options
          ) do
            result = HCA::Service.new.submit_form(get_fixture('hca/short_form'))
            expect(result[:success]).to be(true)
          end
        end

        it 'increments statsd' do
          allow(StatsD).to receive(:increment)

          expect(StatsD).to receive(:increment).with(
            'api.1010ez.submit_form_short_form.fail', tags: ['error:VCRErrorsUnhandledHTTPRequestError']
          )
          expect(StatsD).to receive(:increment).with('api.1010ez.submit_form_short_form.total')

          expect do
            HCA::Service.new.submit_form(get_fixture('hca/short_form'))
          end.to raise_error(StandardError)
        end
      end

      context 'submitting with attachment' do
        context "with the 'ezr_use_correct_format_for_file_uploads' flipper enabled" do
          before do
            allow(Flipper).to receive(:enabled?).and_call_original
            allow(Flipper).to receive(:enabled?).with(:ezr_use_correct_format_for_file_uploads).and_return(true)
          end

          it 'works', with_run_at do
            VCR.use_cassette(
              'hca/submit_with_attachment_formatted_correctly',
              vcr_options
            ) do
              result = HCA::Service.new.submit_form(create(:hca_app_with_attachment).parsed_form)
              expect(result[:success]).to be(true)
              expect(Rails.logger).to have_received(:info).with(
                'Payload for submitted 1010EZ: Body size of 16 KB with 2 attachment(s)'
              )
              expect(Rails.logger).to have_received(:info).with(
                'Attachment sizes in descending order: 1.8 KB, 1.8 KB'
              )
            end
          end

          context 'with a non-pdf attachment' do
            it 'works', with_run_at do
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
                'hca/submit_with_attachment_jpg_formatted_correctly',
                vcr_options
              ) do
                result = HCA::Service.new.submit_form(health_care_application.parsed_form)
                expect(result[:success]).to be(true)
              end
            end
          end
        end

        context "with the 'ezr_use_correct_format_for_file_uploads' flipper disabled" do
          before do
            allow(Flipper).to receive(:enabled?).and_call_original
            allow(Flipper).to receive(:enabled?).with(:ezr_use_correct_format_for_file_uploads).and_return(false)
          end

          it 'works', with_run_at do
            VCR.use_cassette(
              'hca/submit_with_attachment',
              vcr_options
            ) do
              result = HCA::Service.new.submit_form(create(:hca_app_with_attachment).parsed_form)
              expect(result[:success]).to be(true)
              expect(Rails.logger).to have_received(:info).with(
                'Payload for submitted 1010EZ: Body size of 16 KB with 2 attachment(s)'
              )
              expect(Rails.logger).to have_received(:info).with(
                'Attachment sizes in descending order: 1.8 KB, 1.8 KB'
              )
            end
          end

          context 'with a non-pdf attachment' do
            it 'works', with_run_at do
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
                vcr_options
              ) do
                result = HCA::Service.new.submit_form(health_care_application.parsed_form)
                expect(result[:success]).to be(true)
              end
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
            formSubmissionId: HCA::Configuration::HEALTH_CHECK_ID,
            timestamp: '2024-08-20T11:38:44.535-05:00'
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

# rubocop:enable RSpec/ExampleWording
