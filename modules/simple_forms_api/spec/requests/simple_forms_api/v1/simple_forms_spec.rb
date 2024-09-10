# frozen_string_literal: true

require 'rails_helper'
require 'simple_forms_api_submission/metadata_validator'
require 'lighthouse/benefits_intake/service'
require 'common/file_helpers'

RSpec.describe 'SimpleFormsApi::V1::SimpleForms', type: :request do
  forms = [
    # TODO: Restore this test when we release 26-4555 to production.
    # 'vba_26_4555.json',
    'vba_21_4138.json',
    'vba_21_4142.json',
    'vba_21_10210.json',
    'vba_21p_0847.json',
    'vba_21_0972.json',
    'vba_21_0845.json',
    'vba_40_0247.json',
    'vba_21_0966.json',
    'vba_20_10206.json',
    'vba_40_10007.json',
    'vba_20_10207-veteran.json',
    'vba_20_10207-non-veteran.json'
  ]

  unauthenticated_forms = %w[vba_40_0247.json vba_21_10210.json vba_21p_0847.json
                             vba_40_10007.json]
  authenticated_forms = forms - unauthenticated_forms

  describe '#submit' do
    context 'going to Lighthouse Benefits Intake API' do
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
        Flipper.disable(:simple_forms_email_confirmations)
      end

      after do
        VCR.eject_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location')
        VCR.eject_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload')
        Common::FileHelpers.delete_file_if_exists(metadata_file)
        Flipper.enable(:simple_forms_email_confirmations)
      end

      unauthenticated_forms.each do |form|
        fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', form)
        data = JSON.parse(fixture_path.read)

        it 'makes the request' do
          allow(SimpleFormsApiSubmission::MetadataValidator).to receive(:validate)

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(SimpleFormsApiSubmission::MetadataValidator).to have_received(:validate)
          expect(response).to have_http_status(:ok)
        end

        it 'saves a FormSubmissionAttempt' do
          allow(SimpleFormsApiSubmission::MetadataValidator).to receive(:validate)

          expect do
            post '/simple_forms_api/v1/simple_forms', params: data
          end.to change(FormSubmissionAttempt, :count).by(1)
        end
      end

      authenticated_forms.each do |form|
        fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', form)
        data = JSON.parse(fixture_path.read)

        context 'authenticated user' do
          before do
            user = create(:user)
            sign_in_as(user)
            create(:in_progress_form, user_uuid: user.uuid, form_id: data['form_number'])
          end

          fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', form)
          data = JSON.parse(fixture_path.read)

          it 'makes the request' do
            allow(SimpleFormsApiSubmission::MetadataValidator).to receive(:validate)

            post '/simple_forms_api/v1/simple_forms', params: data

            expect(SimpleFormsApiSubmission::MetadataValidator).to have_received(:validate)
            expect(response).to have_http_status(:ok)
          end

          it 'saves a FormSubmissionAttempt' do
            allow(SimpleFormsApiSubmission::MetadataValidator).to receive(:validate)

            expect do
              post '/simple_forms_api/v1/simple_forms', params: data
            end.to change(FormSubmissionAttempt, :count).by(1)
          end

          it 'clears the InProgressForm' do
            allow(SimpleFormsApiSubmission::MetadataValidator).to receive(:validate)

            expect do
              post '/simple_forms_api/v1/simple_forms', params: data
            end.to change(InProgressForm, :count).by(-1)
          end

          it 'sends the PDF to the SimpleFormsApi::S3Service::SubmissionArchiveHandler' do
            hardcoded_location_url = 'https://sandbox-api.va.gov/services_user_content/vba_documents/id-path-doesnt-matter'
            benefits_intake_uuid = 'some-benefits-intake-uuid'
            presigned_s3_url = 'some-presigned-url'
            submission_archive_handler = double(run: presigned_s3_url)
            allow_any_instance_of(BenefitsIntake::Service).to receive(:request_upload)
              .and_return([hardcoded_location_url, benefits_intake_uuid])
            allow(SimpleFormsApi::S3Service::SubmissionArchiveHandler).to receive(:new)
              .with(benefits_intake_uuid:)
              .and_return(submission_archive_handler)

            post '/simple_forms_api/v1/simple_forms', params: data

            expect(submission_archive_handler).to have_received(:run)
            expect(JSON.parse(response.body)['presigned_s3_url']).to eq presigned_s3_url
          end
        end
      end

      context 'request with intent to file' do
        context 'authenticated but without participant_id' do
          before do
            sign_in
            allow_any_instance_of(User).to receive(:icn).and_return('123498767V234859')
            allow_any_instance_of(User).to receive(:participant_id).and_return(nil)
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

          context 'fails to go to Lighthouse Benefits Claims API because of UnprocessableEntity error' do
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
        it 'appends the attachments to the 40-0247 PDF' do
          fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                         'vba_40_0247_with_supporting_document.json')
          pdf_path = Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf')
          data = JSON.parse(fixture_path.read)
          attachment = double
          allow(attachment).to receive(:to_pdf).and_return(pdf_path)

          expect(PersistentAttachment).to receive(:where).with(guid: ['a-random-uuid']).and_return([attachment])

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:ok)
        end

        it 'appends the attachments to the 40-10007 PDF' do
          fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                         'vba_40_10007_with_supporting_document.json')
          pdf_path = Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf')
          data = JSON.parse(fixture_path.read)
          attachment = double
          allow(attachment).to receive(:to_pdf).and_return(pdf_path)
          expect(PersistentAttachment).to receive(:where).with(guid: ['a-random-uuid']).and_return([attachment])
          post '/simple_forms_api/v1/simple_forms', params: data
          expect(response).to have_http_status(:ok)
        end
      end

      context 'LOA3 authenticated' do
        before do
          sign_in
          allow_any_instance_of(User).to receive(:icn).and_return('123498767V234859')
          allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_token')
        end

        it 'stamps the LOA3 text on the PDF' do
          fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                         'vba_21_4142.json')
          data = JSON.parse(fixture_path.read)

          allow(SimpleFormsApiSubmission::MetadataValidator).to receive(:validate)
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
            Flipper.disable(:form21_0966_confirmation_email)

            fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                           'form_with_accented_chars_21_0966.json')
            data = JSON.parse(fixture_path.read)

            post '/simple_forms_api/v1/simple_forms', params: data

            expect(response).to have_http_status(:ok)

            Flipper.enable(:form21_0966_confirmation_email)
          end
        end

        context 'transliteration fails' do
          it 'responds with an error' do
            fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                           'form_with_non_latin_chars_21_0966.json')
            data = JSON.parse(fixture_path.read)

            post '/simple_forms_api/v1/simple_forms', params: data

            expect(response).to have_http_status(:error)
            # 'not compatible' gets mangled by our scrubbing but this indicates that we're getting the right message
            expect(response.body).to include('not copatible with the Windows-15 character set')
          end
        end
      end
    end

    context 'going to Lighthouse Benefits Claims API' do
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
          sign_in
          allow_any_instance_of(User).to receive(:icn).and_return('123498767V234859')
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

    describe 'failed requests scrub PII from error messages' do
      before do
        sign_in
      end

      describe 'unhandled form' do
        it 'makes the request and expects a failure' do
          fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                         'form_with_dangerous_characters_unhandled.json')
          data = JSON.parse(fixture_path.read)

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

      describe '21-4142' do
        it 'makes the request and expects a failure' do
          fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                         'form_with_dangerous_characters_21_4142.json')
          data = JSON.parse(fixture_path.read)

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:error)
          # 'unexpected token at' gets mangled by our scrubbing but this indicates that we're getting the right message
          expect(response.body).to include('unexpected ken at')

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
        it 'makes the request and expects a failure' do
          fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                         'form_with_dangerous_characters_21_10210.json')
          data = JSON.parse(fixture_path.read)

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:error)
          # 'unexpected token at' gets mangled by our scrubbing but this indicates that we're getting the right message
          expect(response.body).to include('unexpected token t')

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
        it 'makes the request and expects a failure' do
          skip 'restore this test when we release the form to production'

          fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                         'form_with_dangerous_characters_26_4555.json')
          data = JSON.parse(fixture_path.read)

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:error)
          expect(response.body).to include('unexpected token at')

          exception = JSON.parse(response.body)['errors'][0]['meta']['exception']
          expect(exception).not_to include(data.dig('veteran', 'ssn')&.[](0..2))
          expect(exception).not_to include(data.dig('veteran', 'ssn')&.[](3..4))
          expect(exception).not_to include(data.dig('veteran', 'ssn')&.[](5..8))
          expect(exception).not_to include(data.dig('veteran', 'address', 'postal_code')&.[](0..4))
        end
      end

      describe '21P-0847' do
        it 'makes the request and expects a failure' do
          fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                         'form_with_dangerous_characters_21P_0847.json')
          data = JSON.parse(fixture_path.read)

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:error)
          # 'unexpected token at' gets mangled by our scrubbing but this indicates that we're getting the right message
          expect(response.body).to include('unexpected token t')

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
        it 'makes the request and expects a failure' do
          fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                         'form_with_dangerous_characters_21_0845.json')
          data = JSON.parse(fixture_path.read)

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:error)
          # 'unexpected token at' gets mangled by our scrubbing but this indicates that we're getting the right message
          expect(response.body).to include('unexpected token t')

          exception = JSON.parse(response.body)['errors'][0]['meta']['exception']
          expect(exception).not_to include(data.dig('authorizer_address', 'postal_code')&.[](0..4))
          expect(exception).not_to include(data['veteran_ssn']&.[](0..2))
          expect(exception).not_to include(data['veteran_ssn']&.[](3..4))
          expect(exception).not_to include(data['veteran_ssn']&.[](5..8))
        end
      end
    end
  end

  describe '#submit_supporting_documents' do
    before do
      sign_in
    end

    it 'renders the attachment as json' do
      clamscan = double(safe?: true)
      allow(Common::VirusScan).to receive(:scan).and_return(clamscan)
      file = fixture_file_upload('doctors-note.gif')

      # Define data for both form IDs
      data_sets = [
        { form_id: '40-0247', file: },
        { form_id: '40-10007', file: }
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
  end

  describe '#get_intents_to_file' do
    before do
      VCR.insert_cassette('lighthouse/benefits_claims/intent_to_file/404_response')
      VCR.insert_cassette('lighthouse/benefits_claims/intent_to_file/404_response_pension')
      VCR.insert_cassette('lighthouse/benefits_claims/intent_to_file/404_response_survivor')
      sign_in
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
        expect(parsed_response['compensation_intent']).to eq nil
        expect(parsed_response['pension_intent']).to eq nil
        expect(parsed_response['survivor_intent']).to eq nil
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
        expect(parsed_response['pension_intent']).to eq nil
        expect(parsed_response['survivor_intent']).to eq nil
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
        expect(parsed_response['compensation_intent']).to eq nil
        expect(parsed_response['pension_intent']['type']).to eq 'pension'
        expect(parsed_response['survivor_intent']).to eq nil
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
        expect(parsed_response['survivor_intent']).to eq nil
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
        expect(parsed_response['compensation_intent']).to eq nil
        expect(parsed_response['pension_intent']).to eq nil
        expect(parsed_response['survivor_intent']).to eq nil
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'email confirmations' do
    before do
      sign_in
    end

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
          .to receive(:upload_pdf).and_return([200, confirmation_number])

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
            'first_name' => 'JACK',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => confirmation_number
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
            'first_name' => 'ARTHUR',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => confirmation_number
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
            'first_name' => 'PREPARE',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => confirmation_number
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
          sign_in_as(user)
          allow_any_instance_of(User).to receive(:va_profile_email).and_return('abraham.lincoln@vets.gov')
          allow_any_instance_of(User).to receive(:participant_id).and_return('fake-participant-id')
          allow(VANotify::EmailJob).to receive(:perform_async)
        end

        context 'veteran preparer' do
          it 'successful submission' do
            allow_any_instance_of(SimpleFormsApi::IntentToFile)
              .to receive(:submit).and_return([confirmation_number, Time.zone.now])
            allow_any_instance_of(SimpleFormsApi::IntentToFile)
              .to receive(:existing_intents)
              .and_return({ 'compensation' => 'false', 'pension' => 'false', 'survivor' => 'false' })

            data['preparer_identification'] = 'VETERAN'

            post '/simple_forms_api/v1/simple_forms', params: data

            expect(response).to have_http_status(:ok)

            expect(VANotify::EmailJob).to have_received(:perform_async).with(
              'abraham.lincoln@vets.gov',
              'form21_0966_confirmation_email_template_id',
              {
                'first_name' => 'ABRAHAM',
                'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
                'confirmation_number' => confirmation_number,
                'intent_to_file_benefits' => 'Survivors Pension and/or Dependency and Indemnity Compensation (DIC)' \
                                             ' (VA Form 21P-534 or VA Form 21P-534EZ)'
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
                'first_name' => 'ABRAHAM',
                'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
                'confirmation_number' => confirmation_number,
                'intent_to_file_benefits' => 'Survivors Pension and/or Dependency and Indemnity Compensation (DIC)' \
                                             ' (VA Form 21P-534 or VA Form 21P-534EZ)'
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
      end
    end
  end
end
