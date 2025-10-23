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

      allow(SimpleFormsApi::PdfStamper).to receive(:new).with(stamped_template_path: pdf_path.to_s, current_loa: 3,
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

    it 'saves the FormSubmission and FormSubmissionAttempt' do
      form_submission = double
      expect(FormSubmission).to receive(:create).with(
        form_type: form_number,
        form_data: params['form_data'].to_json,
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
        expect(resp['errors'][0]).to have_key('detail')
        expect(resp['errors'][0]['detail']).to include('Document exceeds the page size limit of 78 in. x 101 in.')
      end

      it 'returns validation when too many mbs' do
        too_many_mbs_file = fixture_file_upload('doctors-note.pdf', 'application/pdf')
        validation_result = PDFUtilities::PDFValidator::ValidationResult.new
        validation_result.errors << 'file - size must not be greater than 100.0 MB'
        allow_any_instance_of(PDFUtilities::PDFValidator::Validator).to receive(:validate).and_return(validation_result)

        params = { form_id: form_number, file: too_many_mbs_file }

        expect do
          post '/simple_forms_api/v1/supporting_documents_upload', params:
        end.not_to change(PersistentAttachment, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        resp = JSON.parse(response.body)
        expect(resp['errors']).to be_an(Array)
        expect(resp['errors'][0]).to have_key('detail')
        expect(resp['errors'][0]['detail']).to include('file - size must not be greater than 100.0 MB')
      end
    end

    context 'when basic attachment validation fails' do
      before do
        allow(Flipper).to receive(:enabled?).with(:simple_forms_upload_supporting_documents,
                                                  an_instance_of(User)).and_return(true)
      end

      it 'returns validation errors without calling processor' do
        allow_any_instance_of(PersistentAttachments::MilitaryRecords).to receive(:valid?) do |attachment|
          attachment.errors.add(:file, 'is invalid')
          false
        end

        expect(SimpleFormsApi::ScannedFormProcessor).not_to receive(:new)

        params = { form_id: form_number, file: valid_pdf_file }

        post('/simple_forms_api/v1/supporting_documents_upload', params:)

        expect(response).to have_http_status(:unprocessable_entity)
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
  end
end
