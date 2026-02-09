# frozen_string_literal: true

require 'rails_helper'
require 'simple_forms_api_submission/metadata_validator'
require 'common/file_helpers'
require 'lighthouse/benefits_intake/service'
require 'lgy/service'
require 'benefits_intake_service/service'

RSpec.describe 'SimpleFormsApi::V1::SimpleForms', type: :request do
  forms = [
    'vba_20_10206.json',
    'vba_20_10207-non-veteran.json',
    'vba_20_10207-veteran.json',
    'vba_21_0845.json',
    'vba_21_0966.json',
    'vba_21_0972.json',
    'vba_21_10210.json',
    'vba_21_4138.json',
    'vba_21_4140.json',
    'vba_21_4142.json',
    'vba_21p_601.json',
    'vba_21p_0847.json',
    'vba_21p_0537.json',
    'vba_40_0247.json',
    'vba_40_10007.json',
    'vba_40_1330m.json'
  ]

  unauthenticated_forms = %w[
    vba_21_10210.json
    vba_21p_0847.json
    vba_40_0247.json
    vba_40_10007.json
    vba_40_1330m.json
  ]
  authenticated_forms = forms - unauthenticated_forms

  let(:pdf_url) { 'https://s3.com/presigned-goodness' }
  let(:mock_s3_client) { instance_double(SimpleFormsApi::FormRemediation::S3Client) }
  let(:lighthouse_service) { instance_double(BenefitsIntake::Service) }
  let(:user) { create(:user, :legacy_icn, participant_id:) }
  let(:participant_id) { 'some-participant-id' }

  before do
    allow(SimpleFormsApi::FormRemediation::S3Client).to receive(:new).and_return(mock_s3_client)
    allow(mock_s3_client).to receive(:upload).and_return(pdf_url)
    allow(SimpleFormsApiSubmission::MetadataValidator).to receive(:validate)
  end

  describe '#submit' do
    context 'submitting to Lighthouse Benefits Intake API',
            skip: 'flakey specs reported https://dsva.slack.com/archives/C044AGZFG2W/p1745933769157079' do
      let(:metadata_file) { "#{file_seed}.SimpleFormsApi.metadata.json" }
      let(:file_seed) { 'tmp/some-unique-simple-forms-file-seed' }
      let(:random_string) { 'some-unique-simple-forms-file-seed' }

      before do
        VCR.insert_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location')
        VCR.insert_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload')
        allow(Common::FileHelpers).to receive(:random_file_path).and_return(file_seed)
        allow(Common::FileHelpers).to receive(:generate_clamav_temp_file).and_wrap_original do |original_method, *args|
          original_method.call(args[0], random_string)
        end
      end

      after do
        VCR.eject_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location')
        VCR.eject_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload')
        Common::FileHelpers.delete_file_if_exists(metadata_file)
      end

      shared_examples 'form submission' do |form, is_authenticated|
        let(:fixture_path) { Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', form) }
        let(:data) { JSON.parse(fixture_path.read) }

        context "for #{form}" do
          if is_authenticated
            before do
              user = create(:user, :legacy_icn)
              sign_in(user)
              create(:in_progress_form, user_uuid: user.uuid, form_id: data['form_number'])
            end
          end

          it 'validates metadata and responds with status OK' do
            post '/simple_forms_api/v1/simple_forms', params: data

            expect(SimpleFormsApiSubmission::MetadataValidator).to have_received(:validate)
            expect(response).to have_http_status(:ok)
          end

          it 'creates a FormSubmissionAttempt record' do
            expect do
              post '/simple_forms_api/v1/simple_forms', params: data
            end.to change(FormSubmissionAttempt, :count).by(1)
          end

          if is_authenticated
            it 'clears the InProgressForm' do
              initial_count = InProgressForm.count

              post '/simple_forms_api/v1/simple_forms', params: data

              final_count = InProgressForm.count
              expect(final_count).to eq(initial_count - 1)
            end
          end

          it 'sends the PDF to the S3 bucket' do
            location_url = 'https://sandbox-api.va.gov/services_user_content/vba_documents/id-path-doesnt-matter'
            benefits_intake_uuid = SecureRandom.uuid
            allow_any_instance_of(BenefitsIntake::Service).to(
              receive(:request_upload).and_return([location_url, benefits_intake_uuid])
            )

            post '/simple_forms_api/v1/simple_forms', params: data

            expect(mock_s3_client).to have_received(:upload)
            expect(JSON.parse(response.body)['pdf_url']).to eq pdf_url
          end
        end
      end

      describe 'unauthenticated forms' do
        unauthenticated_forms.each do |form|
          it_behaves_like 'form submission', form, false
        end
      end

      describe 'authenticated forms' do
        authenticated_forms.each do |form|
          it_behaves_like 'form submission', form, true
        end
      end

      context 'request with intent to file' do
        context 'authenticated but without participant_id' do
          let(:participant_id) { nil }

          before do
            sign_in(user)
            allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_token')
          end

          context 'veteran' do
            it 'calls #populate_veteran_data' do
              expect_any_instance_of(SimpleFormsApi::VBA210966).to receive(:populate_veteran_data).and_call_original

              fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                             'vba_21_0966-prefill.json')
              data = JSON.parse(fixture_path.read)
              data['preparer_identification'] = 'VETERAN'

              post '/simple_forms_api/v1/simple_forms', params: data
            end
          end

          context 'third party' do
            let(:expiration_date) { Time.zone.now }

            before do
              allow_any_instance_of(ActiveSupport::TimeZone).to receive(:now).and_return(expiration_date)
            end

            %w[THIRD_PARTY_VETERAN THIRD_PARTY_SURVIVING_DEPENDENT].each do |identification|
              it 'returns an expiration date' do
                fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                               'vba_21_0966.json')
                data = JSON.parse(fixture_path.read)
                data['preparer_identification'] = identification

                post '/simple_forms_api/v1/simple_forms', params: data

                parsed_response_body = JSON.parse(response.body)
                parsed_expiration_date = Time.zone.parse(parsed_response_body['expiration_date'])
                expect(parsed_expiration_date.to_s).to eq (expiration_date + 1.year).to_s
              end
            end
          end

          context 'fails to submit to Lighthouse Benefits Claims API because of UnprocessableEntity error' do
            before do
              VCR.insert_cassette('lighthouse/benefits_claims/intent_to_file/422_response')
            end

            after do
              VCR.eject_cassette('lighthouse/benefits_claims/intent_to_file/422_response')
            end

            it 'catches the exception and sends a PDF to Central Mail instead' do
              expect_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(
                :upload_pdf
              ).and_return([:ok, 'confirmation number'])
              fixture_path = Rails.root.join(
                'modules',
                'simple_forms_api',
                'spec',
                'fixtures',
                'form_json',
                'vba_21_0966-min.json'
              )
              data = JSON.parse(fixture_path.read)
              data['preparer_identification'] = 'VETERAN'

              post '/simple_forms_api/v1/simple_forms', params: data

              expect(response).to have_http_status(:ok)
            end
          end
        end
      end

      context 'request with attached documents' do
        let(:pdf_path) { Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf') }
        let(:confirmation_number) { 'some_confirmation_number' }

        before do
          sign_in
          allow(PersistentAttachment).to receive(:where) do |args|
            args[:guid].map { instance_double(PersistentAttachment, to_pdf: pdf_path) }
          end
        end

        shared_examples 'submits successfully' do |form_doc|
          let(:data) do
            fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', form_doc)
            JSON.parse(fixture_path.read)
          end

          it 'returns a 200 OK response' do
            post '/simple_forms_api/v1/simple_forms', params: data
            expect(response).to have_http_status(:ok)
          end
        end

        shared_examples 'handles multiple attachments' do |form_doc|
          before do
            allow(BenefitsIntake::Service).to receive(:new).and_return(lighthouse_service)
            allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to(
              receive(:prepare_for_upload).and_return(%w[location uuid])
            )
            allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to(
              receive(:log_upload_details).and_return(true)
            )
            allow(lighthouse_service).to(
              receive(:perform_upload).and_return(OpenStruct.new(status: 200, confirmation_number:))
            )
          end

          let(:data) do
            fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', form_doc)
            JSON.parse(fixture_path.read)
          end

          it_behaves_like 'submits successfully', form_doc

          it 'calls the lighthouse service with attachments' do
            post '/simple_forms_api/v1/simple_forms', params: data

            expect(lighthouse_service).to have_received(:perform_upload).with(hash_including(:attachments))
          end
        end

        it_behaves_like 'submits successfully', 'vba_40_0247_with_supporting_document.json'
        it_behaves_like 'submits successfully', 'vba_40_10007_with_supporting_document.json'
        it_behaves_like 'handles multiple attachments', 'vba_20_10207_with_supporting_documents.json'
      end

      context 'LOA3 authenticated' do
        before do
          sign_in(user)
          allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_token')
        end

        it 'stamps the LOA3 text on the PDF' do
          fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                         'vba_21_4142.json')
          data = JSON.parse(fixture_path.read)

          expect_any_instance_of(SimpleFormsApi::PdfFiller).to receive(:generate).with(3)

          post '/simple_forms_api/v1/simple_forms', params: data
        end
      end

      context 'transliterating fields' do
        before do
          sign_in
        end

        context 'transliteration succeeds' do
          it 'responds with ok' do
            fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                           'form_with_accented_chars_21_0966.json')
            data = JSON.parse(fixture_path.read)

            post '/simple_forms_api/v1/simple_forms', params: data

            expect(response).to have_http_status(:ok)
          end
        end

        context 'transliteration fails' do
          it 'responds with an error' do
            fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                           'form_with_non_latin_chars_21_0966.json')
            data = JSON.parse(fixture_path.read)

            post '/simple_forms_api/v1/simple_forms', params: data

            expect(response).to have_http_status(:error)

            expect(JSON.parse(response.body, symbolize_names: true)).to include(
              errors: include(
                a_hash_including(
                  title: 'Internal server error',
                  meta: a_hash_including(exception: match(/not compatible with the Windows-1252 character set./))
                )
              )
            )
          end
        end
      end
    end

    context 'submitting to Lighthouse Benefits Claims API' do
      before do
        allow(Common::VirusScan).to receive(:scan).and_return(true)
        VCR.insert_cassette('lighthouse/benefits_claims/intent_to_file/404_response')
        VCR.insert_cassette('lighthouse/benefits_claims/intent_to_file/200_response_pension')
        VCR.insert_cassette('lighthouse/benefits_claims/intent_to_file/200_response_survivor')
        VCR.insert_cassette('lighthouse/benefits_claims/intent_to_file/create_compensation_200_response')
      end

      after do
        VCR.eject_cassette('lighthouse/benefits_claims/intent_to_file/404_response')
        VCR.eject_cassette('lighthouse/benefits_claims/intent_to_file/200_response_pension')
        VCR.eject_cassette('lighthouse/benefits_claims/intent_to_file/200_response_survivor')
        VCR.eject_cassette('lighthouse/benefits_claims/intent_to_file/create_compensation_200_response')
      end

      context 'authenticated' do
        before do
          sign_in(user)
          allow_any_instance_of(User).to receive(:participant_id).and_return('fake-participant-id')
          allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_token')
        end

        context 'request with intent to file' do
          context 'veteran' do
            it 'makes the request with an intent to file' do
              fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                             'vba_21_0966-min.json')
              data = JSON.parse(fixture_path.read)
              data['preparer_identification'] = 'VETERAN'

              post '/simple_forms_api/v1/simple_forms', params: data

              expect(response).to have_http_status(:ok)
            end
          end
        end
      end
    end

    context 'submitting to SAHSHA API (vba_26_4555)' do
      let(:reference_number) { 'some-reference-number' }
      let(:body_status) { 'ACCEPTED' }
      let(:body) { { 'reference_number' => reference_number, 'status' => body_status } }
      let(:status) { 200 }
      let(:lgy_response) { double(body:, status:) }

      before do
        sign_in
        allow_any_instance_of(LGY::Service).to receive(:post_grant_application).and_return(lgy_response)
      end

      it 'makes the request to LGY::Service' do
        fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                       'vba_26_4555.json')
        data = JSON.parse(fixture_path.read)

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:ok)
        parsed_body = JSON.parse(response.body)
        expect(parsed_body['reference_number']).to eq reference_number
        expect(parsed_body['status']).to eq body_status
      end
    end

    describe 'failed requests scrub PII from error messages' do
      let(:data) { JSON.parse(fixture_path.read) }
      let(:fixture_path) do
        Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', form)
      end

      before do
        sign_in
      end

      describe 'unhandled form' do
        let(:form) { 'form_with_dangerous_characters_unhandled.json' }

        it 'makes the request and expects a failure' do
          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:error)
          expect(response.body).to include('something has gone wrong with your form')

          exception = JSON.parse(response.body)['errors'][0]['meta']['exception']
          expect(exception).not_to include(data.dig('veteran', 'ssn')&.[](0..2))
          expect(exception).not_to include(data.dig('veteran', 'ssn')&.[](3..4))
          expect(exception).not_to include(data.dig('veteran', 'ssn')&.[](5..8))
          expect(exception).not_to include(data.dig('veteran', 'address', 'postal_code')&.[](0..4))
        end
      end

      describe '21-4140' do
        let(:form) { 'form_with_dangerous_characters_21_4140.json' }

        it 'makes the request and expects a failure' do
          post '/simple_forms_api/v1/simple_forms', params: data
          expect(response).to have_http_status(:error)
          expect(response.body).to include("expected ',' or '}' after object value, got:")

          exception = JSON.parse(response.body)['errors'][0]['meta']['exception']
          expect(exception).not_to include(data.dig('veteran_id', 'ssn')&.[](0..2))
          expect(exception).not_to include(data.dig('veteran_id', 'ssn')&.[](3..4))
          expect(exception).not_to include(data.dig('veteran_id', 'ssn')&.[](5..8))
          expect(exception).not_to include(data.dig('address', 'street'))
          expect(exception).not_to include(data.dig('address', 'street2'))
          expect(exception).not_to include(data.dig('address', 'street3'))
          expect(exception).not_to include(data.dig('address', 'postal_code'))
        end
      end

      describe '21-4142' do
        let(:form) { 'form_with_dangerous_characters_21_4142.json' }

        it 'makes the request and expects a failure' do
          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:error)
          expect(response.body).to include("expected ',' or '}' after object value, got:")

          exception = JSON.parse(response.body)['errors'][0]['meta']['exception']
          expect(exception).not_to include(data.dig('veteran', 'ssn')&.[](0..2))
          expect(exception).not_to include(data.dig('veteran', 'ssn')&.[](3..4))
          expect(exception).not_to include(data.dig('veteran', 'ssn')&.[](5..8))
          expect(exception).not_to include(data.dig('veteran', 'address', 'street'))
          expect(exception).not_to include(data.dig('veteran', 'address', 'street2'))
          expect(exception).not_to include(data.dig('veteran', 'address', 'street3'))
        end
      end

      describe '21-10210' do
        let(:form) { 'form_with_dangerous_characters_21_10210.json' }

        it 'makes the request and expects a failure' do
          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:error)
          # 'after object value' gets mangled by our scrubbing but this indicates that we're getting the right message
          expect(response.body).to include("expected ',' or '}' fter object vlue, got:")

          exception = JSON.parse(response.body)['errors'][0]['meta']['exception']
          expect(exception).not_to include(data['veteran_ssn']&.[](0..2))
          expect(exception).not_to include(data['veteran_ssn']&.[](3..4))
          expect(exception).not_to include(data['veteran_ssn']&.[](5..8))
          expect(exception).not_to include(data['claimant_ssn']&.[](0..2))
          expect(exception).not_to include(data['claimant_ssn']&.[](3..4))
          expect(exception).not_to include(data['claimant_ssn']&.[](5..8))
        end
      end

      describe '26-4555' do
        let(:form) { 'form_with_dangerous_characters_26_4555.json' }

        it 'makes the request and expects a failure' do
          skip 'restore this test when we release the form to production'

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:error)
          expect(response.body).to include("expected ',' or '}' after object value, got: '  '")

          exception = JSON.parse(response.body)['errors'][0]['meta']['exception']
          expect(exception).not_to include(data.dig('veteran', 'ssn')&.[](0..2))
          expect(exception).not_to include(data.dig('veteran', 'ssn')&.[](3..4))
          expect(exception).not_to include(data.dig('veteran', 'ssn')&.[](5..8))
          expect(exception).not_to include(data.dig('veteran', 'address', 'postal_code')&.[](0..4))
        end
      end

      describe '21P-0847' do
        let(:form) { 'form_with_dangerous_characters_21P_0847.json' }

        it 'makes the request and expects a failure' do
          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:error)
          # 'after object value' gets mangled by our scrubbing but this indicates that we're getting the right message
          expect(response.body).to include("expected ',' or '}' fter object vlue, got:")

          exception = JSON.parse(response.body)['errors'][0]['meta']['exception']
          expect(exception).not_to include(data['preparer_ssn']&.[](0..2))
          expect(exception).not_to include(data['preparer_ssn']&.[](3..4))
          expect(exception).not_to include(data['preparer_ssn']&.[](5..8))
          expect(exception).not_to include(data.dig('preparer_address', 'postal_code')&.[](0..4))
          expect(exception).not_to include(data['veteran_ssn']&.[](0..2))
          expect(exception).not_to include(data['veteran_ssn']&.[](3..4))
          expect(exception).not_to include(data['veteran_ssn']&.[](5..8))
        end
      end

      describe '21-0845' do
        let(:form) { 'form_with_dangerous_characters_21_0845.json' }

        it 'makes the request and expects a failure' do
          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:error)
          # 'after object value' gets mangled by our scrubbing but this indicates that we're getting the right message
          expect(response.body).to include("expected ','  '}' fter object vlue, got:")

          exception = JSON.parse(response.body)['errors'][0]['meta']['exception']
          expect(exception).not_to include(data.dig('authorizer_address', 'postal_code')&.[](0..4))
          expect(exception).not_to include(data['veteran_ssn']&.[](0..2))
          expect(exception).not_to include(data['veteran_ssn']&.[](3..4))
          expect(exception).not_to include(data['veteran_ssn']&.[](5..8))
        end
      end
    end

    describe 'VSI flash feature flag' do
      let(:controller) { SimpleFormsApi::V1::UploadsController.new }
      let(:form) { instance_double(SimpleFormsApi::VBA2010207) }
      let(:submission) { double(id: 123) }
      let(:user) { create(:user, :legacy_icn) }

      before do
        allow(controller).to receive(:params).and_return(ActionController::Parameters.new(form_number: '20-10207'))
        allow(controller).to receive(:instance_variable_get).with('@current_user').and_return(user)
        allow(form).to receive(:respond_to?).with(:add_vsi_flash).and_return(true)
      end

      it 'calls add_vsi_flash when feature flag is enabled' do
        allow(Flipper).to receive(:enabled?).with(:priority_processing_request_apply_vsi_flash, user).and_return(true)
        expect(Rails.logger).to receive(:info).with('Simple Forms API - VSI Flash Applied',
                                                    submission_id: submission.id)
        expect(form).to receive(:add_vsi_flash)
        controller.send(:add_vsi_flash_safely, form, submission)
      end

      it 'does not call add_vsi_flash when feature flag is disabled' do
        allow(Flipper).to receive(:enabled?).with(:priority_processing_request_apply_vsi_flash, user).and_return(false)
        allow(form).to receive(:add_vsi_flash) { raise 'should not be called' }
        expect { controller.send(:add_vsi_flash_safely, form, submission) }.not_to raise_error
      end
    end
  end

  describe '#submit_supporting_documents' do
    before do
      sign_in
    end

    let(:valid_file) { fixture_file_upload('doctors-note.pdf') }
    let(:invalid_file) { fixture_file_upload('too_large.pdf') }

    it 'renders the attachment as json when the document is valid' do
      clamscan = double(safe?: true)
      allow(Common::VirusScan).to receive(:scan).and_return(clamscan)

      # Stub the BenefitsIntakeService for validation
      valid_service = double(valid_document?: true)
      allow(BenefitsIntakeService::Service).to receive(:new).and_return(valid_service)

      data_sets = [
        { form_id: '40-0247', file: valid_file },
        { form_id: '40-10007', file: valid_file },
        { form_id: '40-1330M', file: valid_file }
      ]

      data_sets.each do |data|
        expect do
          post '/simple_forms_api/v1/simple_forms/submit_supporting_documents', params: data
        end.to change(PersistentAttachment, :count).by(1)

        expect(response).to have_http_status(:ok)
        resp = JSON.parse(response.body)
        expect(resp['data']['attributes'].keys.sort).to eq(%w[confirmation_code name size])
        expect(PersistentAttachment.last).to be_a(PersistentAttachments::MilitaryRecords)
      end
    end

    it 'returns an error when the document validation fails' do
      clamscan = double(safe?: true)
      allow(Common::VirusScan).to receive(:scan).and_return(clamscan)

      invalid_service = double
      error = BenefitsIntakeService::Service::InvalidDocumentError.new('Invalid file format')
      allow(invalid_service).to receive(:valid_document?).and_raise(error)

      allow(BenefitsIntakeService::Service).to receive(:new).and_return(invalid_service)

      data = { form_id: '40-0247', file: invalid_file }

      expect do
        post '/simple_forms_api/v1/simple_forms/submit_supporting_documents', params: data
      end.not_to change(PersistentAttachment, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      resp = JSON.parse(response.body)
      expect(resp['error']).to eq 'Document validation failed: Invalid file format'
    end

    it 'returns an error when the attachment is invalid' do
      clamscan = double(safe?: true)
      allow(Common::VirusScan).to receive(:scan).and_return(clamscan)

      allow_any_instance_of(PersistentAttachments::MilitaryRecords).to receive(:valid?).and_return(false)

      data = { form_id: '40-0247', file: invalid_file }

      expect do
        post '/simple_forms_api/v1/simple_forms/submit_supporting_documents', params: data
      end.not_to change(PersistentAttachment, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns a user-friendly error message when document validation fails for form 40-10007' do
      clamscan = double(safe?: true)
      allow(Common::VirusScan).to receive(:scan).and_return(clamscan)

      invalid_service = double
      error = BenefitsIntakeService::Service::InvalidDocumentError.new('Invalid file format')
      allow(invalid_service).to receive(:valid_document?).and_raise(error)

      allow(BenefitsIntakeService::Service).to receive(:new).and_return(invalid_service)

      data = { form_id: '40-10007', file: invalid_file }

      expect do
        post '/simple_forms_api/v1/simple_forms/submit_supporting_documents', params: data
      end.not_to change(PersistentAttachment, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      resp = JSON.parse(response.body)
      expect(resp['errors']).to be_an(Array)
      expect(resp['errors'][0]['detail']).to eq(
        "We weren't able to upload your file. Make sure the file is in an accepted format and size before continuing."
      )
    end

    it 'skips document validation for non-PDF files' do
      clamscan = double(safe?: true)
      allow(Common::VirusScan).to receive(:scan).and_return(clamscan)

      # Mock a non-PDF file
      non_pdf_file = fixture_file_upload('doctors-note.gif')

      # BenefitsIntakeService should not be called for non-PDF files
      expect(BenefitsIntakeService::Service).not_to receive(:new)

      data = { form_id: '40-0247', file: non_pdf_file }

      expect do
        post '/simple_forms_api/v1/simple_forms/submit_supporting_documents', params: data
      end.to change(PersistentAttachment, :count).by(1)

      expect(response).to have_http_status(:ok)
    end

    it 'skips document validation for form types that do not require it' do
      clamscan = double(safe?: true)
      allow(Common::VirusScan).to receive(:scan).and_return(clamscan)

      # BenefitsIntakeService should not be called for form 20-10207
      expect(BenefitsIntakeService::Service).not_to receive(:new)

      data = { form_id: '20-10207', file: valid_file }

      expect do
        post '/simple_forms_api/v1/simple_forms/submit_supporting_documents', params: data
      end.to change(PersistentAttachment, :count).by(1)

      expect(response).to have_http_status(:ok)
    end
  end

  describe '#get_intents_to_file' do
    let(:participant_id) { '123456789' }
    let(:mpi_profile) { build(:mpi_profile, participant_id:) }

    before do
      VCR.insert_cassette('lighthouse/benefits_claims/intent_to_file/404_response')
      VCR.insert_cassette('lighthouse/benefits_claims/intent_to_file/404_response_pension')
      VCR.insert_cassette('lighthouse/benefits_claims/intent_to_file/404_response_survivor')
      allow_any_instance_of(MPIData).to receive(:profile).and_return(mpi_profile)
      sign_in(user)

      allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_token')
    end

    after do
      VCR.eject_cassette('lighthouse/benefits_claims/intent_to_file/404_response')
      VCR.eject_cassette('lighthouse/benefits_claims/intent_to_file/404_response_pension')
      VCR.eject_cassette('lighthouse/benefits_claims/intent_to_file/404_response_survivor')
    end

    describe 'no intents on file' do
      it 'returns no intents' do
        get '/simple_forms_api/v1/simple_forms/get_intents_to_file'

        parsed_response = JSON.parse(response.body)
        expect(parsed_response['compensation_intent']).to be_nil
        expect(parsed_response['pension_intent']).to be_nil
        expect(parsed_response['survivor_intent']).to be_nil
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'compensation intent on file' do
      before do
        VCR.insert_cassette('lighthouse/benefits_claims/intent_to_file/200_response')
      end

      after do
        VCR.eject_cassette('lighthouse/benefits_claims/intent_to_file/200_response')
      end

      it 'returns a compensation intent' do
        get '/simple_forms_api/v1/simple_forms/get_intents_to_file'

        parsed_response = JSON.parse(response.body)
        expect(parsed_response['compensation_intent']['type']).to eq 'compensation'
        expect(parsed_response['pension_intent']).to be_nil
        expect(parsed_response['survivor_intent']).to be_nil
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'pension intent on file' do
      before do
        VCR.insert_cassette('lighthouse/benefits_claims/intent_to_file/200_response_pension')
      end

      after do
        VCR.eject_cassette('lighthouse/benefits_claims/intent_to_file/200_response_pension')
      end

      it 'returns a pension intent' do
        get '/simple_forms_api/v1/simple_forms/get_intents_to_file'

        parsed_response = JSON.parse(response.body)
        expect(parsed_response['compensation_intent']).to be_nil
        expect(parsed_response['pension_intent']['type']).to eq 'pension'
        expect(parsed_response['survivor_intent']).to be_nil
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'both intents on file' do
      before do
        VCR.insert_cassette('lighthouse/benefits_claims/intent_to_file/200_response')
        VCR.insert_cassette('lighthouse/benefits_claims/intent_to_file/200_response_pension')
      end

      after do
        VCR.eject_cassette('lighthouse/benefits_claims/intent_to_file/200_response')
        VCR.eject_cassette('lighthouse/benefits_claims/intent_to_file/200_response_pension')
      end

      it 'returns a pension intent' do
        get '/simple_forms_api/v1/simple_forms/get_intents_to_file'

        parsed_response = JSON.parse(response.body)
        expect(parsed_response['compensation_intent']['type']).to eq 'compensation'
        expect(parsed_response['pension_intent']['type']).to eq 'pension'
        expect(parsed_response['survivor_intent']).to be_nil
        expect(response).to have_http_status(:ok)
      end
    end

    context 'no participant_id' do
      before do
        allow_any_instance_of(User).to receive(:participant_id).and_return(nil)
      end

      it 'returns no intents' do
        get '/simple_forms_api/v1/simple_forms/get_intents_to_file'

        parsed_response = JSON.parse(response.body)
        expect(parsed_response['compensation_intent']).to be_nil
        expect(parsed_response['pension_intent']).to be_nil
        expect(parsed_response['survivor_intent']).to be_nil
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'email confirmations' do
    let(:confirmation_number) { 'some_confirmation_number' }

    before do
      sign_in(user)
      allow(Flipper).to receive(:enabled?).with(:simple_forms_email_delivery_callback).and_return(true)
    end

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
          .to receive(:upload_pdf).and_return([200, confirmation_number])

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:ok)

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'veteran.surname@address.com',
          'form21_4142_confirmation_email_template_id',
          {
            'first_name' => 'Veteran',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => confirmation_number
          },
          'fake_secret',
          {
            callback_klass: 'SimpleFormsApi::Notification::EmailDeliveryStatusCallback',
            callback_metadata: {
              notification_type: 'confirmation',
              form_number: 'vba_21_4142',
              confirmation_number:,
              statsd_tags: {
                'service' => 'veteran-facing-forms',
                'function' => 'vba_21_4142 form submission to Lighthouse'
              }
            }
          }
        )
      end

      it 'unsuccessful submission' do
        allow(VANotify::EmailJob).to receive(:perform_async)
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController)
          .to receive(:upload_pdf).and_return([500, confirmation_number])

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
          .to receive(:upload_pdf).and_return([200, confirmation_number])

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:ok)

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'my.long.email.address@email.com',
          'form21_10210_confirmation_email_template_id',
          {
            'first_name' => 'Jack',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => confirmation_number
          },
          'fake_secret',
          {
            callback_klass: 'SimpleFormsApi::Notification::EmailDeliveryStatusCallback',
            callback_metadata: {
              notification_type: 'confirmation',
              form_number: 'vba_21_10210',
              confirmation_number:,
              statsd_tags: {
                'service' => 'veteran-facing-forms',
                'function' => 'vba_21_10210 form submission to Lighthouse'
              }
            }
          }
        )
      end

      it 'unsuccessful submission' do
        allow(VANotify::EmailJob).to receive(:perform_async)
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController)
          .to receive(:upload_pdf).and_return([500, confirmation_number])

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

        allow_any_instance_of(SimpleFormsApi::V1::UploadsController)
          .to receive(:upload_pdf).and_return([200, confirmation_number])

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:ok)

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'preparer_address@email.com',
          'form21p_0847_confirmation_email_template_id',
          {
            'first_name' => 'Arthur',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => confirmation_number
          },
          'fake_secret',
          {
            callback_klass: 'SimpleFormsApi::Notification::EmailDeliveryStatusCallback',
            callback_metadata: {
              notification_type: 'confirmation',
              form_number: 'vba_21p_0847',
              confirmation_number:,
              statsd_tags: {
                'service' => 'veteran-facing-forms',
                'function' => 'vba_21p_0847 form submission to Lighthouse'
              }
            }
          }
        )
      end

      it 'unsuccessful submission' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        allow_any_instance_of(SimpleFormsApi::V1::UploadsController)
          .to receive(:upload_pdf).and_return([500, confirmation_number])

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
          .to receive(:upload_pdf).and_return([200, confirmation_number])

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:ok)

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'preparer@email.com',
          'form21_0972_confirmation_email_template_id',
          {
            'first_name' => 'Prepare',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => confirmation_number
          },
          'fake_secret',
          {
            callback_klass: 'SimpleFormsApi::Notification::EmailDeliveryStatusCallback',
            callback_metadata: {
              notification_type: 'confirmation',
              form_number: 'vba_21_0972',
              confirmation_number:,
              statsd_tags: {
                'service' => 'veteran-facing-forms',
                'function' => 'vba_21_0972 form submission to Lighthouse'
              }
            }
          }
        )
      end

      it 'unsuccessful submission' do
        allow(VANotify::EmailJob).to receive(:perform_async)
        allow_any_instance_of(SimpleFormsApi::PdfUploader)
          .to receive(:upload_to_benefits_intake).and_return([500, confirmation_number])

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:error)

        expect(VANotify::EmailJob).not_to have_received(:perform_async)
      end
    end

    describe '21_0966' do
      context 'authenticated user' do
        let(:data) do
          fixture_path = Rails.root.join(
            'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_21_0966.json'
          )
          JSON.parse(fixture_path.read)
        end

        before do
          user = create(:user)
          sign_in(user)
          allow_any_instance_of(User).to receive(:va_profile_email).and_return('abraham.lincoln@vets.gov')
          allow_any_instance_of(User).to receive(:participant_id).and_return('fake-participant-id')
          allow(VANotify::EmailJob).to receive(:perform_async)
          allow(Flipper).to receive(:enabled?).with(:simple_forms_email_delivery_callback).and_return(true)
        end

        context 'veteran preparer' do
          let(:expiration_date) { '2026-01-14T09:25:55-06:00' }

          it 'sends the received email' do
            allow_any_instance_of(SimpleFormsApi::IntentToFile)
              .to receive(:submit).and_return([confirmation_number, expiration_date])
            allow_any_instance_of(SimpleFormsApi::IntentToFile)
              .to receive(:existing_intents)
              .and_return({ 'compensation' => 'false', 'pension' => 'false', 'survivor' => 'false' })

            data['preparer_identification'] = 'VETERAN'

            post '/simple_forms_api/v1/simple_forms', params: data

            expect(response).to have_http_status(:ok)

            expect(VANotify::EmailJob).to have_received(:perform_async).with(
              'abraham.lincoln@vets.gov',
              'form21_0966_itf_api_received_email_template_id',
              {
                'first_name' => 'Veteran',
                'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
                'confirmation_number' => confirmation_number,
                'intent_to_file_benefits' => 'survivors pension benefits',
                'intent_to_file_benefits_links' => '[Apply for DIC, Survivors Pension, and/or Accrued Benefits ' \
                                                   '(VA Form 21P-534EZ)](https://www.va.gov/find-forms/about-form-21p-534ez/)',
                'itf_api_expiration_date' => 'January 14, 2026'
              },
              'fake_secret',
              {
                callback_klass: 'SimpleFormsApi::Notification::EmailDeliveryStatusCallback',
                callback_metadata: {
                  notification_type: 'received',
                  form_number: 'vba_21_0966_intent_api',
                  confirmation_number:,
                  statsd_tags: {
                    'service' => 'veteran-facing-forms',
                    'function' => 'vba_21_0966_intent_api form submission to Lighthouse'
                  }
                }
              }
            )
          end
        end

        context 'non-veteran preparer' do
          it 'successful submission' do
            allow_any_instance_of(SimpleFormsApi::V1::UploadsController)
              .to receive(:upload_pdf).and_return([200, confirmation_number])

            post '/simple_forms_api/v1/simple_forms', params: data

            expect(response).to have_http_status(:ok)

            expect(VANotify::EmailJob).to have_received(:perform_async).with(
              'abraham.lincoln@vets.gov',
              'form21_0966_confirmation_email_template_id',
              {
                'first_name' => 'Veteran',
                'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
                'confirmation_number' => confirmation_number,
                'intent_to_file_benefits' => 'survivors pension benefits',
                'intent_to_file_benefits_links' => '[Apply for DIC, Survivors Pension, and/or Accrued Benefits ' \
                                                   '(VA Form 21P-534EZ)](https://www.va.gov/find-forms/about-form-21p-534ez/)',
                'itf_api_expiration_date' => nil
              },
              'fake_secret',
              {
                callback_klass: 'SimpleFormsApi::Notification::EmailDeliveryStatusCallback',
                callback_metadata: {
                  notification_type: 'confirmation',
                  form_number: 'vba_21_0966',
                  confirmation_number:,
                  statsd_tags: {
                    'service' => 'veteran-facing-forms',
                    'function' => 'vba_21_0966 form submission to Lighthouse'
                  }
                }
              }
            )
          end

          it 'unsuccessful submission' do
            allow_any_instance_of(SimpleFormsApi::PdfUploader)
              .to receive(:upload_to_benefits_intake).and_return([500, confirmation_number])

            post '/simple_forms_api/v1/simple_forms', params: data

            expect(response).to have_http_status(:error)

            expect(VANotify::EmailJob).not_to have_received(:perform_async)
          end
        end

        context 'no new intent to file added' do
          before do
            allow_any_instance_of(SimpleFormsApi::IntentToFile).to receive(:submit).and_return([nil, Time.zone.now])
            allow_any_instance_of(SimpleFormsApi::IntentToFile)
              .to receive(:existing_intents)
              .and_return({ 'compensation' => {}, 'pension' => {}, 'survivor' => {} })
          end

          it 'does not send a confirmation email' do
            data['preparer_identification'] = 'VETERAN'

            post '/simple_forms_api/v1/simple_forms', params: data

            expect(response).to have_http_status(:ok)
            expect(VANotify::EmailJob).not_to have_received(:perform_async)
          end
        end
      end
    end

    describe '26_4555' do
      let(:data) do
        fixture_path = Rails.root.join(
          'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_26_4555.json'
        )
        JSON.parse(fixture_path.read)
      end

      context 'validated or accepted' do
        let(:reference_number) { 'some-reference-number' }
        let(:body_status) { 'VALIDATED' }
        let(:body) { { 'reference_number' => reference_number, 'status' => body_status } }
        let(:status) { 200 }
        let(:lgy_response) { double(body:, status:) }

        before do
          sign_in
          allow_any_instance_of(LGY::Service).to receive(:post_grant_application).and_return(lgy_response)
          allow(Flipper).to receive(:enabled?).with(:simple_forms_email_delivery_callback).and_return(true)
        end

        it 'sends a confirmation email' do
          allow(VANotify::EmailJob).to receive(:perform_async)

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:ok)

          expect(VANotify::EmailJob).to have_received(:perform_async).with(
            'veteran.surname@address.com',
            'form26_4555_confirmation_email_template_id',
            {
              'first_name' => 'Veteran',
              'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
              'confirmation_number' => reference_number
            },
            'fake_secret',
            {
              callback_klass: 'SimpleFormsApi::Notification::EmailDeliveryStatusCallback',
              callback_metadata: {
                notification_type: 'confirmation',
                form_number: 'vba_26_4555',
                confirmation_number: reference_number,
                statsd_tags: {
                  'service' => 'veteran-facing-forms',
                  'function' => 'vba_26_4555 form submission to Lighthouse'
                }
              }
            }
          )
        end
      end

      context 'rejected' do
        let(:reference_number) { 'some-reference-number' }
        let(:body_status) { 'REJECTED' }
        let(:body) { { 'reference_number' => reference_number, 'status' => body_status } }
        let(:status) { 200 }
        let(:lgy_response) { double(body:, status:) }

        before do
          sign_in
          allow_any_instance_of(LGY::Service).to receive(:post_grant_application).and_return(lgy_response)
          allow(Flipper).to receive(:enabled?).with(:simple_forms_email_delivery_callback).and_return(true)
        end

        it 'sends a rejected email' do
          allow(VANotify::EmailJob).to receive(:perform_async)

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:ok)

          expect(VANotify::EmailJob).to have_received(:perform_async).with(
            'veteran.surname@address.com',
            'form26_4555_rejected_email_template_id',
            {
              'first_name' => 'Veteran',
              'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
              'confirmation_number' => reference_number
            },
            'fake_secret',
            {
              callback_klass: 'SimpleFormsApi::Notification::EmailDeliveryStatusCallback',
              callback_metadata: {
                notification_type: 'rejected',
                form_number: 'vba_26_4555',
                confirmation_number: reference_number,
                statsd_tags: {
                  'service' => 'veteran-facing-forms',
                  'function' => 'vba_26_4555 form submission to Lighthouse'
                }
              }
            }
          )
        end
      end

      context 'duplicate' do
        let(:body_status) { 'DUPLICATE' }
        let(:body) { { 'status' => body_status } }
        let(:status) { 200 }
        let(:lgy_response) { double(body:, status:) }

        before do
          sign_in
          allow_any_instance_of(LGY::Service).to receive(:post_grant_application).and_return(lgy_response)
          allow(Flipper).to receive(:enabled?).with(:simple_forms_email_delivery_callback).and_return(true)
        end

        it 'sends a duplicate email' do
          allow(VANotify::EmailJob).to receive(:perform_async)

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:ok)

          expect(VANotify::EmailJob).to have_received(:perform_async).with(
            'veteran.surname@address.com',
            'form26_4555_duplicate_email_template_id',
            {
              'first_name' => 'Veteran',
              'date_submitted' => Time.zone.today.strftime('%B %d, %Y')
            },
            'fake_secret',
            {
              callback_klass: 'SimpleFormsApi::Notification::EmailDeliveryStatusCallback',
              callback_metadata: {
                notification_type: 'duplicate',
                form_number: 'vba_26_4555',
                confirmation_number: nil,
                statsd_tags: {
                  'service' => 'veteran-facing-forms',
                  'function' => 'vba_26_4555 form submission to Lighthouse'
                }
              }
            }
          )
        end
      end
    end
  end

  describe 'Form 40-1330M with attachments' do
    let(:fixture_path) do
      Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_40_1330m.json')
    end
    let(:form_data) { JSON.parse(fixture_path.read) }
    let(:file_seed) { 'tmp/some-unique-simple-forms-file-seed' }
    let(:random_string) { 'some-unique-simple-forms-file-seed' }
    let(:metadata_file) { "#{file_seed}.SimpleFormsApi.metadata.json" }

    before do
      VCR.insert_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location')
      VCR.insert_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload')
      allow(SimpleFormsApiSubmission::MetadataValidator).to receive(:validate)
      allow(Common::FileHelpers).to receive(:random_file_path).and_return(file_seed)
      allow(Common::FileHelpers).to receive(:generate_clamav_temp_file).and_wrap_original do |original_method, *args|
        original_method.call(args[0], random_string)
      end
    end

    after do
      VCR.eject_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location')
      VCR.eject_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload')
      Common::FileHelpers.delete_file_if_exists(metadata_file)
    end

    context 'with supporting documents' do
      let(:attachment) { create(:persistent_attachment_va_form, form_id: '40-1330M') }
      let(:data_with_attachments) do
        form_data.merge(
          'veteran_supporting_documents' => [
            { 'confirmation_code' => attachment.guid }
          ]
        )
      end

      it 'successfully submits form with supporting documents' do
        allow_any_instance_of(PersistentAttachment).to receive(:to_pdf).and_return(
          Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf').to_s
        )

        post '/simple_forms_api/v1/simple_forms', params: data_with_attachments

        expect(response).to have_http_status(:ok)
        resp = JSON.parse(response.body)
        expect(resp['confirmation_number']).to be_present
      end
    end

    context 'with additional_address' do
      let(:data_with_additional_address) do
        form_data.merge(
          'additional_address' => {
            'street' => '123 Main St',
            'city' => 'Seattle',
            'state' => 'WA',
            'postal_code' => '98101',
            'country' => 'USA'
          }
        )
      end

      it 'successfully submits form with additional_address' do
        post '/simple_forms_api/v1/simple_forms', params: data_with_additional_address

        expect(response).to have_http_status(:ok)
        resp = JSON.parse(response.body)
        expect(resp['confirmation_number']).to be_present
      end
    end

    context 'with both supporting documents and additional_address' do
      let(:attachment) { create(:persistent_attachment_va_form, form_id: '40-1330M') }
      let(:data_with_both) do
        form_data.merge(
          'veteran_supporting_documents' => [
            { 'confirmation_code' => attachment.guid }
          ],
          'additional_address' => {
            'street' => '789 Pine St',
            'city' => 'Portland',
            'state' => 'OR',
            'postal_code' => '97202',
            'country' => 'USA'
          }
        )
      end

      it 'successfully submits form with both attachments and additional address' do
        allow_any_instance_of(PersistentAttachment).to receive(:to_pdf).and_return(
          Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf').to_s
        )

        post '/simple_forms_api/v1/simple_forms', params: data_with_both

        expect(response).to have_http_status(:ok)
        resp = JSON.parse(response.body)
        expect(resp['confirmation_number']).to be_present
      end
    end
  end
end
