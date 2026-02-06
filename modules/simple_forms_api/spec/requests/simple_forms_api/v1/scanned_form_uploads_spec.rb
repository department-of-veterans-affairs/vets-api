# frozen_string_literal: true

require 'rails_helper'
require 'simple_forms_api_submission/metadata_validator'
require 'common/file_helpers'

RSpec.describe 'SimpleFormsApi::V1::ScannedFormsUploader', type: :request do
  let(:user) { build(:user, :loa3) }
  let(:form_number) { '21-0779' }
  let(:valid_pdf_file) { fixture_file_upload('doctors-note.pdf', 'application/pdf') }
  let(:valid_image_file) { fixture_file_upload('doctors-note.jpg', 'image/jpeg') }
  let(:large_file) { fixture_file_upload('too_large.pdf', 'application/pdf') }

  before do
    sign_in(user)
  end

  describe '#submit' do
    let(:fixture_path) do
      Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', '21_0779_upload.json')
    end
    let(:params) { JSON.parse(fixture_path.read) }
    let(:form_name) { 'Request for Nursing Home Information in Connection with Claim for Aid and Attendance' }
    let(:metadata_file) { "#{file_seed}.SimpleFormsApi.metadata.json" }
    let(:file_seed) { 'tmp/some-unique-simple-forms-file-seed' }
    let(:random_string) { 'some-unique-simple-forms-file-seed' }
    let(:pdf_path) { Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf') }
    let(:pdf_stamper) { double(stamp_pdf: nil) }
    let(:confirmation_code) { '123456' }
    let(:attachment) { double }

    before do
      allow(Flipper).to receive(:enabled?).with(:simple_forms_upload_supporting_documents,
                                                an_instance_of(User)).and_return(false)
      VCR.insert_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location')
      VCR.insert_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload')
      allow(Common::FileHelpers).to receive(:random_file_path).and_return(file_seed)
      allow(Common::FileHelpers).to receive(:generate_clamav_temp_file).and_wrap_original do |original_method, *args|
        original_method.call(args[0], random_string)
      end

      allow(SimpleFormsApi::PdfStamper).to receive(:new).with(stamped_template_path: pdf_path.to_s,
                                                              current_loa: 3, form_number:,
                                                              timestamp: anything).and_return(pdf_stamper)
      allow(attachment).to receive(:to_pdf).and_return(pdf_path)
      allow(PersistentAttachment).to receive(:find_by).with(guid: confirmation_code).and_return(attachment)
    end

    after do
      VCR.eject_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location')
      VCR.eject_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload')
      Common::FileHelpers.delete_file_if_exists(metadata_file)
    end

    it 'makes the request' do
      post('/simple_forms_api/v1/submit_scanned_form', params:)

      expect(response).to have_http_status(:ok)
    end

    it 'stamps the pdf' do
      expect(pdf_stamper).to receive(:stamp_pdf)

      post('/simple_forms_api/v1/submit_scanned_form', params:)

      expect(response).to have_http_status(:ok)
    end

    it 'saves the FormSubmission and FormSubmissionAttempt with flat data structure' do
      form_submission = double
      expected_form_data = params['form_data'].merge(
        'confirmation_code' => params['confirmation_code'],
        'supporting_documents' => params['supporting_documents'] || []
      ).to_json

      expect(FormSubmission).to receive(:create).with(
        form_type: form_number,
        form_data: expected_form_data,
        user_account: user.user_account
      ).and_return(form_submission)

      expect(FormSubmissionAttempt).to receive(:create).with(
        form_submission:,
        benefits_intake_uuid: anything
      )

      post('/simple_forms_api/v1/submit_scanned_form', params:)

      expect(response).to have_http_status(:ok)
    end

    it 'checks if the prefill data has been changed' do
      prefill_data = double
      prefill_data_service = double
      in_progress_form = double(form_data: prefill_data)

      allow(SimpleFormsApi::PrefillDataService).to receive(:new).with(
        prefill_data:,
        form_data: hash_including(:email),
        form_id: form_number
      ).and_return(prefill_data_service)
      allow(InProgressForm).to receive(:form_for_user).with('FORM-UPLOAD-FLOW',
                                                            anything).and_return(in_progress_form)

      expect(prefill_data_service).to receive(:check_for_changes)

      post('/simple_forms_api/v1/submit_scanned_form', params:)

      expect(response).to have_http_status(:ok)
    end

    context 'when supporting documents feature is enabled' do
      let(:upload_service) { instance_double(SimpleFormsApi::ScannedFormUploadService) }

      before do
        allow(Flipper).to receive(:enabled?).with(:simple_forms_upload_supporting_documents,
                                                  an_instance_of(User)).and_return(true)
        allow(SimpleFormsApi::ScannedFormUploadService).to receive(:new).and_return(upload_service)
        allow(upload_service).to receive(:upload_with_supporting_documents).and_return([200, 'uuid-123'])
      end

      it 'returns success response' do
        post('/simple_forms_api/v1/submit_scanned_form', params:)

        expect(response).to have_http_status(:ok)
        resp = JSON.parse(response.body)
        expect(resp['status']).to eq(200)
        expect(resp['confirmation_number']).to eq('uuid-123')
      end

      it 'passes normalized params with symbol keys to the service' do
        post('/simple_forms_api/v1/submit_scanned_form', params:)

        expect(SimpleFormsApi::ScannedFormUploadService).to have_received(:new) do |args|
          expect(args[:params][:form_number]).to eq(form_number)
          expect(args[:params][:confirmation_code]).to eq(confirmation_code)
          expect(args[:params][:form_data]).to be_a(Hash)
          expect(args[:params][:form_data][:full_name]).to eq({ first: 'John', last: 'Veteran' })
          expect(args[:params][:form_data][:email]).to be_present
          expect(args[:params][:supporting_documents]).to eq([
                                                               {
                                                                 confirmation_code: '23456'
                                                               },
                                                               {
                                                                 confirmation_code: '34567'
                                                               }
                                                             ])
        end
      end

      context 'with supporting documents' do
        let(:params_with_supporting_docs) do
          parsed = JSON.parse(fixture_path.read)
          parsed['supporting_documents'] = [
            { 'confirmation_code' => 'support-1' },
            { 'confirmation_code' => 'support-2' }
          ]
          parsed
        end

        it 'passes supporting documents with symbol keys to the service' do
          post('/simple_forms_api/v1/submit_scanned_form', params: params_with_supporting_docs)

          expect(SimpleFormsApi::ScannedFormUploadService).to have_received(:new) do |args|
            expect(args[:params][:supporting_documents]).to eq([
                                                                 { confirmation_code: 'support-1' },
                                                                 { confirmation_code: 'support-2' }
                                                               ])
          end
        end
      end
    end

    context 'when supporting document submission fails at Lighthouse' do
      let(:upload_error) do
        SimpleFormsApi::ScannedFormUploadService::UploadError.new(
          'Supporting document submission failed',
          errors: [{ title: 'Submission failed', detail: 'Try again later.' }],
          http_status: :bad_gateway
        )
      end

      before do
        allow(Flipper).to receive(:enabled?).with(:simple_forms_upload_supporting_documents,
                                                  an_instance_of(User)).and_return(true)
        service_instance = instance_double(SimpleFormsApi::ScannedFormUploadService)
        allow(SimpleFormsApi::ScannedFormUploadService).to receive(:new).and_return(service_instance)
        allow(service_instance).to receive(:upload_with_supporting_documents).and_raise(upload_error)
      end

      it 'returns the error response from the service' do
        post('/simple_forms_api/v1/submit_scanned_form', params:)

        expect(response).to have_http_status(:bad_gateway)
        resp = JSON.parse(response.body)
        expect(resp['errors'].first['title']).to eq('Submission failed')
        expect(resp['errors'].first['detail']).to eq('Try again later.')
      end
    end
  end

  describe '#upload_scanned_form' do
    it 'renders the attachment as json' do
      clamscan = double(safe?: true)
      allow(Common::VirusScan).to receive(:scan).and_return(clamscan)
      file = fixture_file_upload('doctors-note.gif')

      params = { form_id: form_number, file: }

      expect do
        post '/simple_forms_api/v1/scanned_form_upload', params:
      end.to change(PersistentAttachment, :count).by(1)

      expect(response).to have_http_status(:ok)
      resp = JSON.parse(response.body)
      expect(resp['data']['attributes'].keys.sort).to eq(%w[confirmation_code name size warnings])
      expect(PersistentAttachment.last).to be_a(PersistentAttachments::VAForm)
    end
  end

  describe '#upload_supporting_documents' do
    let(:valid_pdf_file) { fixture_file_upload('doctors-note.pdf', 'application/pdf') }
    let(:valid_image_file) { fixture_file_upload('doctors-note.jpg', 'image/jpeg') }
    let(:large_file) { fixture_file_upload('too_large.pdf', 'application/pdf') }

    before do
      clamscan = double(safe?: true)
      allow(Common::VirusScan).to receive(:scan).and_return(clamscan)
    end

    context 'when feature toggles' do
      before do
        allow(Flipper).to receive(:enabled?).with(:simple_forms_upload_supporting_documents,
                                                  an_instance_of(User)).and_return(true)
      end

      it 'processes files through ScannedFormProcessor and returns success' do
        expect(SimpleFormsApi::ScannedFormProcessor).to receive(:new) do |attachment|
          expect(attachment).to be_a(PersistentAttachments::MilitaryRecords)
          expect(attachment.form_id).to eq(form_number)
          processor = double('ScannedFormProcessor')
          allow(processor).to receive(:process!) do
            attachment.save!
            attachment
          end
          processor
        end

        params = { form_id: form_number, file: valid_pdf_file }

        expect do
          post '/simple_forms_api/v1/supporting_documents_upload', params:
        end.to change(PersistentAttachment, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(PersistentAttachment.last).to be_a(PersistentAttachments::MilitaryRecords)
      end
    end

    context 'when file parameter is missing' do
      before do
        allow(Flipper).to receive(:enabled?).with(:simple_forms_upload_supporting_documents,
                                                  an_instance_of(User)).and_return(true)
      end

      it 'returns a bad request error without processing the upload' do
        expect do
          post '/simple_forms_api/v1/supporting_documents_upload', params: { form_id: form_number }
        end.not_to change(PersistentAttachment, :count)

        expect(response).to have_http_status(:bad_request)
        resp = JSON.parse(response.body)
        expect(resp['errors'].first['title']).to eq('File missing')
      end
    end

    context 'when file parameter is invalid' do
      before do
        allow(Flipper).to receive(:enabled?).with(:simple_forms_upload_supporting_documents,
                                                  an_instance_of(User)).and_return(true)
      end

      it 'returns an unprocessable entity error' do
        expect do
          post '/simple_forms_api/v1/supporting_documents_upload', params: { form_id: form_number, file: 'invalid' }
        end.not_to change(PersistentAttachment, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        resp = JSON.parse(response.body)
        expect(resp['errors'].first['title']).to eq('Invalid file')
      end
    end

    context 'when the processor cannot persist the attachment' do
      let(:persistence_error) do
        SimpleFormsApi::ScannedFormProcessor::PersistenceError.new(
          'File upload failed',
          [{ title: 'File upload failed', detail: 'Database unavailable' }]
        )
      end

      before do
        allow(Flipper).to receive(:enabled?).with(:simple_forms_upload_supporting_documents,
                                                  an_instance_of(User)).and_return(true)
        processor_instance = instance_double(SimpleFormsApi::ScannedFormProcessor)
        allow(SimpleFormsApi::ScannedFormProcessor).to receive(:new).and_return(processor_instance)
        allow(processor_instance).to receive(:process!).and_raise(persistence_error)
      end

      it 'renders a 500 error response' do
        params = { form_id: form_number, file: valid_pdf_file }

        expect do
          post '/simple_forms_api/v1/supporting_documents_upload', params:
        end.not_to change(PersistentAttachment, :count)

        expect(response).to have_http_status(:internal_server_error)
        resp = JSON.parse(response.body)
        expect(resp['errors'].first['detail']).to eq('Database unavailable')
      end
    end

    context 'when file size exceeds limit' do
      before do
        allow(Flipper).to receive(:enabled?).with(:simple_forms_upload_supporting_documents,
                                                  an_instance_of(User)).and_return(true)
      end

      it 'returns validation error for large file' do
        params = { form_id: form_number, file: large_file }

        expect do
          post '/simple_forms_api/v1/supporting_documents_upload', params:
        end.not_to change(PersistentAttachment, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        resp = JSON.parse(response.body)
        expect(resp['errors']).to be_an(Array)
        expect(resp['errors'][0]).to have_key('title')
        expect(resp['errors'][0]['title']).to eq('File validation error')
        expect(resp['errors'][0]).to have_key('detail')
        expect(resp['errors'][0]['detail']).to include('Document exceeds the page size limit of 78 in. x 101 in.')
      end

      it 'returns validation when too many mbs' do
        too_many_mbs_file = fixture_file_upload('doctors-note.pdf', 'application/pdf')

        validation_result = PDFUtilities::PDFValidator::ValidationResult.new
        validation_result.errors << 'file - size must not be greater than 100.0 MB'

        validator_double = instance_double(PDFUtilities::PDFValidator::Validator)
        allow(validator_double).to receive(:validate).and_return(validation_result)
        allow(PDFUtilities::PDFValidator::Validator).to receive(:new).and_return(validator_double)

        params = { form_id: form_number, file: too_many_mbs_file }

        expect do
          post '/simple_forms_api/v1/supporting_documents_upload', params:
        end.not_to change(PersistentAttachment, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        resp = JSON.parse(response.body)
        expect(resp['errors']).to be_an(Array)
        expect(resp['errors'][0]).to have_key('title')
        expect(resp['errors'][0]).to have_key('detail')
        expect(resp['errors'][0]['detail']).to include('file - size must not be greater than 100.0 MB')
      end
    end

    context 'when basic attachment validation fails' do
      before do
        allow(Flipper).to receive(:enabled?).with(:simple_forms_upload_supporting_documents,
                                                  an_instance_of(User)).and_return(true)
      end
    end

    context 'when feature toggle is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:simple_forms_upload_supporting_documents,
                                                  an_instance_of(User)).and_return(false)
      end

      it 'returns not found' do
        params = { form_id: '123', file: valid_pdf_file }
        post('/simple_forms_api/v1/supporting_documents_upload', params:)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with encrypted PDF and password' do
      let(:encrypted_pdf_file) { fixture_file_upload('test_encryption.pdf', 'application/pdf') }
      let(:correct_password) { 'test' }
      let(:wrong_password) { 'wrongpassword' }

      before do
        allow(Flipper).to receive(:enabled?).with(:simple_forms_upload_supporting_documents,
                                                  an_instance_of(User)).and_return(true)
      end

      it 'passes password to processor and processes successfully' do
        expect(SimpleFormsApi::ScannedFormProcessor).to receive(:new) do |attachment, password:|
          expect(attachment).to be_a(PersistentAttachments::MilitaryRecords)
          expect(password).to eq(correct_password)
          processor = double('ScannedFormProcessor')
          allow(processor).to receive(:process!) do
            attachment.save!
            attachment
          end
          processor
        end

        params = { form_id: form_number, file: encrypted_pdf_file, password: correct_password }

        expect do
          post '/simple_forms_api/v1/supporting_documents_upload', params:
        end.to change(PersistentAttachment, :count).by(1)

        expect(response).to have_http_status(:ok)
      end

      it 'successfully processes encrypted PDF end-to-end with real decryption' do
        params = { form_id: form_number, file: encrypted_pdf_file, password: correct_password }
        expect do
          post '/simple_forms_api/v1/supporting_documents_upload', params:
        end.to change(PersistentAttachment, :count).by(1)

        expect(response).to have_http_status(:ok)

        resp = JSON.parse(response.body)
        expect(resp['data']).to be_present
        expect(resp['data']['attributes']).to have_key('confirmation_code')

        attachment = PersistentAttachment.last
        expect(attachment).to be_a(PersistentAttachments::MilitaryRecords)
        expect(attachment.file.content_type).to eq('application/pdf')

        pdf_content = attachment.file.read
        expect(pdf_content).to start_with('%PDF-')
      end

      it 'returns error when wrong password provided' do
        params = { form_id: form_number, file: encrypted_pdf_file, password: wrong_password }

        post('/simple_forms_api/v1/supporting_documents_upload', params:)

        expect(response).to have_http_status(:unprocessable_entity)

        resp = JSON.parse(response.body)
        expect(resp['errors']).to be_an(Array)
        expect(resp['errors'].first).to have_key('title')
        expect(resp['errors'].first).to have_key('detail')
        expect(resp['errors'].first['title']).to eq('Invalid password')
      end

      it 'returns error when encrypted PDF uploaded without password' do
        params = { form_id: form_number, file: encrypted_pdf_file }

        post('/simple_forms_api/v1/supporting_documents_upload', params:)

        expect(response).to have_http_status(:unprocessable_entity)

        resp = JSON.parse(response.body)
        expect(resp['errors']).to be_an(Array)
        expect(resp['errors'].first['detail']).to match(/password|locked|encrypted/i)
      end
    end
  end

  describe 'PII/PHI filtering in logs' do
    let(:fixture_path) do
      Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', '21_0779_upload.json')
    end
    let(:params) { JSON.parse(fixture_path.read) }
    let(:pdf_path) { Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf') }
    let(:pdf_stamper) { double(stamp_pdf: nil) }
    let(:attachment) { double }
    let(:confirmation_code) { '123456' }
    let(:file_seed) { 'tmp/some-unique-simple-forms-file-seed' }
    let(:random_string) { 'some-unique-simple-forms-file-seed' }
    let(:metadata_file) { "#{file_seed}.SimpleFormsApi.metadata.json" }

    before do
      allow(Flipper).to receive(:enabled?).with(:simple_forms_upload_supporting_documents,
                                                an_instance_of(User)).and_return(false)
      VCR.insert_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location')
      VCR.insert_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload')
      allow(Common::FileHelpers).to receive(:random_file_path).and_return(file_seed)
      allow(Common::FileHelpers).to receive(:generate_clamav_temp_file).and_wrap_original do |original_method, *args|
        original_method.call(args[0], random_string)
      end

      allow(SimpleFormsApi::PdfStamper).to receive(:new).with(stamped_template_path: pdf_path.to_s, current_loa: 3,
                                                              form_number:, timestamp: anything).and_return(pdf_stamper)
      allow(attachment).to receive(:to_pdf).and_return(pdf_path)
      allow(PersistentAttachment).to receive(:find_by).with(guid: confirmation_code).and_return(attachment)

      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
    end

    after do
      VCR.eject_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location')
      VCR.eject_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload')
      Common::FileHelpers.delete_file_if_exists(metadata_file)
    end

    describe '#submit' do
      context 'when upload succeeds' do
        it 'includes ParameterFilterHelper module in controller' do
          expect(SimpleFormsApi::V1::ScannedFormUploadsController).to include(Logging::Helper::ParameterFilter)
        end

        it 'logs with filtered parameters only (no PII)' do
          post('/simple_forms_api/v1/submit_scanned_form', params:)

          expect(response).to have_http_status(:ok)

          expect(Rails.logger).to have_received(:info).with(
            'Simple forms api - scanned form uploaded',
            hash_including(
              form_number:,
              status: kind_of(Integer),
              confirmation_number: kind_of(String),
              file_size: kind_of(Float)
            )
          )
        end

        it 'logs only safe parameters in upload response' do
          post('/simple_forms_api/v1/submit_scanned_form', params:)

          expect(response).to have_http_status(:ok)

          expect(Rails.logger).to have_received(:info).with(
            'Simple forms api - scanned form uploaded',
            hash_including(
              form_number: kind_of(String),
              status: kind_of(Integer),
              confirmation_number: kind_of(String),
              file_size: kind_of(Float)
            )
          )
        end

        it 'logs uuid in upload details logging' do
          post('/simple_forms_api/v1/submit_scanned_form', params:)

          expect(response).to have_http_status(:ok)

          expect(Rails.logger).to have_received(:info).with(
            'Simple forms api - preparing to upload scanned PDF to benefits intake',
            hash_including(uuid: kind_of(String))
          ).at_least(:once)
        end
      end
    end

    describe 'Datadog tracing tags' do
      it 'tags with form_id only' do
        post('/simple_forms_api/v1/submit_scanned_form', params:)

        expect(response).to have_http_status(:ok)
      end
    end

    describe 'VA.gov PII/PHI compliance' do
      it 'uses allowlist approach in upload_response_legacy logging' do
        post('/simple_forms_api/v1/submit_scanned_form', params:)

        expect(response).to have_http_status(:ok)

        expect(Rails.logger).to have_received(:info).with(
          'Simple forms api - scanned form uploaded',
          hash_including(
            form_number: kind_of(String),
            status: kind_of(Integer),
            confirmation_number: kind_of(String),
            file_size: kind_of(Float)
          )
        )
      end

      it 'filters location from upload details logging' do
        post('/simple_forms_api/v1/submit_scanned_form', params:)

        expect(response).to have_http_status(:ok)

        expect(Rails.logger).to have_received(:info).with(
          'Simple forms api - preparing to upload scanned PDF to benefits intake',
          hash_including(uuid: kind_of(String))
        )
      end

      it 'includes ParameterFilterHelper in controller' do
        expect(SimpleFormsApi::V1::ScannedFormUploadsController.included_modules).to include(Logging::Helper::ParameterFilter)
      end
    end
  end
end
