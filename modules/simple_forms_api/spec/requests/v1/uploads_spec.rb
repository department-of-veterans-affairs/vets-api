# frozen_string_literal: true

require 'rails_helper'
require 'simple_forms_api_submission/metadata_validator'

RSpec.describe 'Dynamic forms uploader', type: :request do
  describe 'form request' do
    let(:client_stub) { instance_double(CentralMail::Service) }
    let :multipart_request_matcher do
      lambda do |r1, r2|
        [r1, r2].each { |r| normalized_multipart_request(r) }
        expect(r1.headers).to eq(r2.headers)
      end
    end

    def self.test_submit_request(test_payload)
      it 'makes the request' do
        VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
          VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
            fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', test_payload)
            data = JSON.parse(fixture_path.read)
            allow(SimpleFormsApiSubmission::MetadataValidator).to receive(:validate)

            post '/simple_forms_api/v1/simple_forms', params: data

            expect(response).to have_http_status(:ok)
            expect(SimpleFormsApiSubmission::MetadataValidator).to have_received(:validate)
          ensure
            metadata_file = Dir['tmp/*.SimpleFormsApi.metadata.json'][0]
            Common::FileHelpers.delete_file_if_exists(metadata_file) if defined?(metadata_file)
          end
        end
      end
    end

    test_submit_request 'vha_10_10d.json'
    test_submit_request 'vba_26_4555.json'
    test_submit_request 'vba_21_4142.json'
    test_submit_request 'vba_21_10210.json'
    test_submit_request 'vba_21p_0847.json'
    test_submit_request 'vba_21_0972.json'
    test_submit_request 'vba_21_0845.json'
    test_submit_request 'vba_40_0247.json'
    test_submit_request 'vba_21_0966.json'
    test_submit_request 'vba_20_10206.json'
    test_submit_request 'vba_40_10007.json'

    def self.test_saves_form_submission_attempt(test_payload)
      it 'saves a FormSubmissionAttempt' do
        VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
          VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
            fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', test_payload)
            data = JSON.parse(fixture_path.read)
            allow(SimpleFormsApiSubmission::MetadataValidator).to receive(:validate)

            expect do
              post '/simple_forms_api/v1/simple_forms', params: data
            end.to change(FormSubmissionAttempt, :count).by(1)
          ensure
            metadata_file = Dir['tmp/*.SimpleFormsApi.metadata.json'][0]
            Common::FileHelpers.delete_file_if_exists(metadata_file) if defined?(metadata_file)
          end
        end
      end
    end

    test_saves_form_submission_attempt 'vha_10_10d.json'
    test_saves_form_submission_attempt 'vba_26_4555.json'
    test_saves_form_submission_attempt 'vba_21_4142.json'
    test_saves_form_submission_attempt 'vba_21_10210.json'
    test_saves_form_submission_attempt 'vba_21p_0847.json'
    test_saves_form_submission_attempt 'vba_21_0972.json'
    test_saves_form_submission_attempt 'vba_21_0845.json'
    test_saves_form_submission_attempt 'vba_40_0247.json'
    test_saves_form_submission_attempt 'vba_21_0966.json'
    test_saves_form_submission_attempt 'vba_20_10206.json'
    test_saves_form_submission_attempt 'vba_40_10007.json'

    describe 'request with intent to file unauthenticated' do
      let(:expiration_date) { Time.zone.now }

      before do
        allow_any_instance_of(ActiveSupport::TimeZone).to receive(:now).and_return(expiration_date)
      end

      it 'returns an expiration date' do
        VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
          VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
            fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                           'vba_21_0966.json')
            data = JSON.parse(fixture_path.read)

            post '/simple_forms_api/v1/simple_forms', params: data

            parsed_response_body = JSON.parse(response.body)
            parsed_expiration_date = Time.zone.parse(parsed_response_body['expiration_date'])
            expect(parsed_expiration_date.to_s).to eq (expiration_date + 1.year).to_s
          end
        end
      end
    end

    describe 'request with intent to file authenticated' do
      before do
        sign_in
        allow_any_instance_of(User).to receive(:icn).and_return('123498767V234859')
        allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_token')
      end

      it 'makes the request with an intent to file' do
        VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/404_response') do
          VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/200_response_pension') do
            VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/200_response_survivor') do
              VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/create_compensation_200_response') do
                fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                               'vba_21_0966-min.json')
                data = JSON.parse(fixture_path.read)

                post '/simple_forms_api/v1/simple_forms', params: data

                expect(response).to have_http_status(:ok)
              end
            end
          end
        end
      end
    end

    describe '21-4142 form resubmission' do
      it 'generates the right PDF' do
        VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
          VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
            fixture_path = Rails.root.join(
              'modules',
              'simple_forms_api',
              'spec',
              'fixtures',
              'form_json',
              'vba_21_4142_resubmission.json'
            )
            data = JSON.parse(fixture_path.read)

            post '/simple_forms_api/v1/simple_forms', params: data

            expect(response).to have_http_status(:ok)
          ensure
            metadata_file = Dir['tmp/*.SimpleFormsApi.metadata.json'][0]
            Common::FileHelpers.delete_file_if_exists(metadata_file) if defined?(metadata_file)
          end
        end
      end
    end

    def self.test_submit_supporting_documents(form_number)
      it 'renders the attachment as json for form #{test_payload}' do
        allow(ClamScan::Client).to receive(:scan)
          .and_return(instance_double(ClamScan::Response, safe?: true))
        file = fixture_file_upload('doctors-note.gif')
        data = { form_id: form_number, file: file }
    
        expect do
          post '/simple_forms_api/v1/simple_forms/submit_supporting_documents', params: data
        end.to change(PersistentAttachment, :count).by(1)
    
        expect(response).to have_http_status(:ok)
        resp = JSON.parse(response.body)
        expect(resp['data']['attributes'].keys.sort).to eq(%w[confirmation_code name size])
    
        if form_number == '40-0247'
          expect(PersistentAttachment.last).to be_a(PersistentAttachments::MilitaryRecords)
        elsif form_number == '40-10007'
          expect(PersistentAttachment.last).to be_a(PersistentAttachments::PensionBurial)
        end
      end
    end
    

    test_submit_supporting_documents '40-10007' 

    def self.test_submit_form_with_attachments(test_payload)
      it 'appends the attachments to the PDF' do
        VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
          VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
            fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', test_payload)
            pdf_path = Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf')
            data = JSON.parse(fixture_path.read)
            attachment = double
            allow(attachment).to receive(:to_pdf).and_return(pdf_path)
            allow(PersistentAttachment).to receive(:where).with(guid: ['a-random-uuid']).and_return([attachment])

            post '/simple_forms_api/v1/simple_forms', params: data

             expect(response).to have_http_status(:ok)
          ensure
            metadata_file = Dir['tmp/*.SimpleFormsApi.metadata.json'][0]
            Common::FileHelpers.delete_file_if_exists(metadata_file) if defined?(metadata_file)
          end
        end
      end
    end

    test_submit_form_with_attachments 'vba_40_0247_with_supporting_document.json'
    test_submit_form_with_attachments 'vba_40_10007_with_supporting_document.json'

    def self.test_failed_request_scrubs_error_message_unhandled_form
      it 'makes the request for an unhandled form and expects a failure' do
        fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                       'form_with_dangerous_characters_unhandled.json')
        data = JSON.parse(fixture_path.read)

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:error)
        expect(response.body).to include('something has gone wrong with your form')
        expect(response.body).not_to include(data.dig('veteran', 'ssn')&.[](0..2))
        expect(response.body).not_to include(data.dig('veteran', 'ssn')&.[](3..4))
        expect(response.body).not_to include(data.dig('veteran', 'ssn')&.[](5..8))
        expect(response.body).not_to include(data.dig('veteran', 'address', 'postal_code')&.[](0..4))
      end
    end

    test_failed_request_scrubs_error_message_unhandled_form

    def self.test_failed_request_scrubs_error_message214142
      it 'makes the request for 21-4142 and expects a failure' do
        fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                       'form_with_dangerous_characters_21_4142.json')
        data = JSON.parse(fixture_path.read)

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:error)
        # 'unexpected token at' gets mangled by our scrubbing but this indicates that we're getting the right message
        expect(response.body).to include('unexpected ken at')
        expect(response.body).not_to include(data.dig('veteran', 'ssn')&.[](0..2))
        expect(response.body).not_to include(data.dig('veteran', 'ssn')&.[](3..4))
        expect(response.body).not_to include(data.dig('veteran', 'ssn')&.[](5..8))
        expect(response.body).not_to include(data.dig('veteran', 'address', 'street'))
        expect(response.body).not_to include(data.dig('veteran', 'address', 'street2'))
        expect(response.body).not_to include(data.dig('veteran', 'address', 'street3'))
      end
    end

    test_failed_request_scrubs_error_message214142

    def self.test_failed_request_scrubs_error_message2110210
      it 'makes the request for 21-10210 and expects a failure' do
        fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                       'form_with_dangerous_characters_21_10210.json')
        data = JSON.parse(fixture_path.read)

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:error)
        # 'unexpected token at' gets mangled by our scrubbing but this indicates that we're getting the right message
        expect(response.body).to include('unexpected token t')
        expect(response.body).not_to include(data['veteran_ssn']&.[](0..2))
        expect(response.body).not_to include(data['veteran_ssn']&.[](3..4))
        expect(response.body).not_to include(data['veteran_ssn']&.[](5..8))
        expect(response.body).not_to include(data['claimant_ssn']&.[](0..2))
        expect(response.body).not_to include(data['claimant_ssn']&.[](3..4))
        expect(response.body).not_to include(data['claimant_ssn']&.[](5..8))
      end
    end

    test_failed_request_scrubs_error_message2110210

    def self.test_failed_request_scrubs_error_message264555
      it 'makes the request for 26-4555 and expects a failure' do
        fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                       'form_with_dangerous_characters_26_4555.json')
        data = JSON.parse(fixture_path.read)

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:error)
        expect(response.body).to include('unexpected token at')
        expect(response.body).not_to include(data.dig('veteran', 'ssn')&.[](0..2))
        expect(response.body).not_to include(data.dig('veteran', 'ssn')&.[](3..4))
        expect(response.body).not_to include(data.dig('veteran', 'ssn')&.[](5..8))
        expect(response.body).not_to include(data.dig('veteran', 'address', 'postal_code')&.[](0..4))
      end
    end

    test_failed_request_scrubs_error_message264555

    def self.test_failed_request_scrubs_error_message21p0847
      it 'makes the request for 21P-0847 and expects a failure' do
        fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                       'form_with_dangerous_characters_21P_0847.json')
        data = JSON.parse(fixture_path.read)

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:error)
        # 'unexpected token at' gets mangled by our scrubbing but this indicates that we're getting the right message
        expect(response.body).to include('unexpected token t')
        expect(response.body).not_to include(data['preparer_ssn']&.[](0..2))
        expect(response.body).not_to include(data['preparer_ssn']&.[](3..4))
        expect(response.body).not_to include(data['preparer_ssn']&.[](5..8))
        expect(response.body).not_to include(data.dig('preparer_address', 'postal_code')&.[](0..4))
        expect(response.body).not_to include(data['veteran_ssn']&.[](0..2))
        expect(response.body).not_to include(data['veteran_ssn']&.[](3..4))
        expect(response.body).not_to include(data['veteran_ssn']&.[](5..8))
      end
    end

    test_failed_request_scrubs_error_message21p0847

    def self.test_failed_request_scrubs_error_message210845
      it 'makes the request for 21-0845 and expects a failure' do
        fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                       'form_with_dangerous_characters_21_0845.json')
        data = JSON.parse(fixture_path.read)

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:error)
        # 'unexpected token at' gets mangled by our scrubbing but this indicates that we're getting the right message
        expect(response.body).to include('unexpected token t')
        expect(response.body).not_to include(data.dig('authorizer_address', 'postal_code')&.[](0..4))
        expect(response.body).not_to include(data['veteran_ssn']&.[](0..2))
        expect(response.body).not_to include(data['veteran_ssn']&.[](3..4))
        expect(response.body).not_to include(data['veteran_ssn']&.[](5..8))
      end
    end

    test_failed_request_scrubs_error_message210845

    describe 'email confirmations' do
      let(:confirmation_number) { 'some_confirmation_number' }

      describe '21_4142' do
        let(:data) do
          fixture_path = Rails.root.join(
            'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_21_4142.json'
          )
          JSON.parse(fixture_path.read)
        end

        it 'successful submission' do
          allow(VANotify::EmailJob).to receive(:perform_async)
          allow_any_instance_of(SimpleFormsApi::V1::UploadsController)
            .to receive(:upload_pdf_to_benefits_intake).and_return([200, confirmation_number])

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:ok)

          expect(VANotify::EmailJob).to have_received(:perform_async).with(
            'veteran.surname@address.com',
            'form21_4142_confirmation_email_template_id',
            {
              'first_name' => 'VETERAN',
              'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
              'confirmation_number' => confirmation_number
            }
          )
        end

        it 'unsuccessful submission' do
          allow(VANotify::EmailJob).to receive(:perform_async)
          allow_any_instance_of(SimpleFormsApi::V1::UploadsController)
            .to receive(:upload_pdf_to_benefits_intake).and_return([500, confirmation_number])

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:error)

          expect(VANotify::EmailJob).not_to have_received(:perform_async)
        end
      end

      describe '21_10210' do
        let(:data) do
          fixture_path = Rails.root.join(
            'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_21_10210.json'
          )
          JSON.parse(fixture_path.read)
        end

        it 'successful submission' do
          allow(VANotify::EmailJob).to receive(:perform_async)
          allow_any_instance_of(SimpleFormsApi::V1::UploadsController)
            .to receive(:upload_pdf_to_benefits_intake).and_return([200, confirmation_number])

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:ok)

          expect(VANotify::EmailJob).to have_received(:perform_async).with(
            'my.long.email.address@email.com',
            'form21_10210_confirmation_email_template_id',
            {
              'first_name' => 'JACK',
              'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
              'confirmation_number' => confirmation_number
            }
          )
        end

        it 'unsuccessful submission' do
          allow(VANotify::EmailJob).to receive(:perform_async)
          allow_any_instance_of(SimpleFormsApi::V1::UploadsController)
            .to receive(:upload_pdf_to_benefits_intake).and_return([500, confirmation_number])

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:error)

          expect(VANotify::EmailJob).not_to have_received(:perform_async)
        end
      end

      describe '21p_0847' do
        let(:data) do
          fixture_path = Rails.root.join(
            'modules',
            'simple_forms_api',
            'spec',
            'fixtures',
            'form_json',
            'vba_21p_0847.json'
          )
          JSON.parse(fixture_path.read)
        end

        it 'successful submission' do
          allow(VANotify::EmailJob).to receive(:perform_async)

          allow_any_instance_of(
            SimpleFormsApi::V1::UploadsController
          ).to receive(
            :upload_pdf_to_benefits_intake
          ).and_return([200, confirmation_number])

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:ok)

          expect(VANotify::EmailJob).to have_received(:perform_async).with(
            'preparer_address@email.com',
            'form21p_0847_confirmation_email_template_id',
            {
              'first_name' => 'ARTHUR',
              'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
              'confirmation_number' => confirmation_number
            }
          )
        end

        it 'unsuccessful submission' do
          allow(VANotify::EmailJob).to receive(:perform_async)

          allow_any_instance_of(
            SimpleFormsApi::V1::UploadsController
          ).to receive(
            :upload_pdf_to_benefits_intake
          ).and_return([500, confirmation_number])

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:error)

          expect(VANotify::EmailJob).not_to have_received(:perform_async)
        end
      end

      describe '21_0972' do
        let(:data) do
          fixture_path = Rails.root.join(
            'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_21_0972.json'
          )
          JSON.parse(fixture_path.read)
        end

        it 'successful submission' do
          allow(VANotify::EmailJob).to receive(:perform_async)
          allow_any_instance_of(SimpleFormsApi::V1::UploadsController)
            .to receive(:upload_pdf_to_benefits_intake).and_return([200, confirmation_number])

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:ok)

          expect(VANotify::EmailJob).to have_received(:perform_async).with(
            'preparer@email.com',
            'form21_0972_confirmation_email_template_id',
            {
              'first_name' => 'PREPARE',
              'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
              'confirmation_number' => confirmation_number
            }
          )
        end

        it 'unsuccessful submission' do
          allow(VANotify::EmailJob).to receive(:perform_async)
          allow_any_instance_of(SimpleFormsApi::V1::UploadsController)
            .to receive(:upload_pdf_to_benefits_intake).and_return([500, confirmation_number])

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:error)

          expect(VANotify::EmailJob).not_to have_received(:perform_async)
        end
      end
    end
  end
end
