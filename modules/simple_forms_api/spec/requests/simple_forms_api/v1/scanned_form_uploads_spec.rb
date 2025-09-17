# frozen_string_literal: true

require 'rails_helper'
require 'simple_forms_api_submission/metadata_validator'
require 'common/file_helpers'

RSpec.describe 'SimpleFormsApi::V1::ScannedFormsUploader', type: :request do
  let(:user) { build(:user, :loa3) }
  let(:form_number) { '21-0779' }

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
    let(:confirmation_code) { params['confirmation_code'] }
    let(:main_attachment) { double('MainAttachment') }

    before do
      VCR.insert_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location')
      VCR.insert_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload')
      allow(Common::FileHelpers).to receive(:random_file_path).and_return(file_seed)
      allow(Common::FileHelpers).to receive(:generate_clamav_temp_file).and_wrap_original do |original_method, *args|
        original_method.call(args[0], random_string)
      end

      allow(SimpleFormsApi::PdfStamper).to receive(:new).with(
        stamped_template_path: pdf_path.to_s,
        current_loa: 3,
        timestamp: anything
      ).and_return(pdf_stamper)

      file_mock = double('file')
      allow(file_mock).to receive(:open).and_return(double(path: pdf_path.to_s))
      allow(main_attachment).to receive(:file).and_return(file_mock)
      allow(PersistentAttachment).to receive(:find_by).with(guid: confirmation_code).and_return(main_attachment)
      allow(PersistentAttachment).to receive(:where).with(guid: []).and_return([])
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

    context 'successful processing' do
      it 'processes files through ScannedFormProcessor and returns success' do
        expect(SimpleFormsApi::ScannedFormProcessor).to receive(:new) do |attachment|
          expect(attachment).to be_a(PersistentAttachments::VAForm)
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
        expect(PersistentAttachment.last).to be_a(PersistentAttachments::VAForm)
      end
    end

    context 'when conversion fails' do
      it 'returns conversion error from processor' do
        processor = double('ScannedFormProcessor')
        expect(SimpleFormsApi::ScannedFormProcessor).to receive(:new).and_return(processor)
        expect(processor).to receive(:process!).and_raise(
          SimpleFormsApi::ScannedFormProcessor::ConversionError.new(
            'File conversion failed',
            [{ title: 'File conversion error',
               detail: 'Unable to convert file to PDF. Please ensure your file is valid and try again.' }]
          )
        )

        params = { form_id: form_number, file: valid_image_file }

        expect do
          post '/simple_forms_api/v1/supporting_documents_upload', params:
        end.not_to change(PersistentAttachment, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        resp = JSON.parse(response.body)
        expect(resp['errors']).to be_an(Array)
        expect(resp['errors'][0]['detail']).to include('Unable to convert file to PDF')
      end
    end

    context 'when validation fails' do
      it 'returns validation error from processor' do
        processor = double('ScannedFormProcessor')
        expect(SimpleFormsApi::ScannedFormProcessor).to receive(:new).and_return(processor)
        expect(processor).to receive(:process!).and_raise(
          SimpleFormsApi::ScannedFormProcessor::ValidationError.new(
            'PDF validation failed',
            [{ title: 'File validation error', detail: 'Document exceeds the file size limit of 100 MB' }]
          )
        )

        params = { form_id: form_number, file: large_file }

        expect do
          post '/simple_forms_api/v1/supporting_documents_upload', params:
        end.not_to change(PersistentAttachment, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        resp = JSON.parse(response.body)
        expect(resp['errors']).to be_an(Array)
        expect(resp['errors'][0]['detail']).to include('file size limit')
      end
    end

    context 'when basic attachment validation fails' do
      it 'returns validation errors without calling processor' do
        allow_any_instance_of(PersistentAttachments::VAForm).to receive(:valid?) do |attachment|
          attachment.errors.add(:file, 'is invalid')
          false
        end

        expect(SimpleFormsApi::ScannedFormProcessor).not_to receive(:new)

        params = { form_id: form_number, file: valid_pdf_file }

        post('/simple_forms_api/v1/supporting_documents_upload', params:)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe '#submit with supporting evidence' do
    let(:fixture_path) do
      Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', '21_0779_upload.json')
    end
    let(:base_params) { JSON.parse(fixture_path.read) }
    let(:main_confirmation_code) { base_params['confirmation_code'] }
    let(:supporting_evidence_codes) { %w[support-1 support-2] }
    let(:params_with_supporting_evidence) do
      base_params.merge(
        'supporting_documents' => [
          { 'confirmation_code' => 'support-1' },
          { 'confirmation_code' => 'support-2' }
        ]
      )
    end
    let(:pdf_path) { Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf') }
    let(:metadata_file) { "#{file_seed}.SimpleFormsApi.metadata.json" }
    let(:file_seed) { 'tmp/some-unique-simple-forms-file-seed' }

    before do
      VCR.insert_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location')
      VCR.insert_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload')
      allow(Common::FileHelpers).to receive(:random_file_path).and_return(file_seed)
      allow(Common::FileHelpers).to receive(:generate_clamav_temp_file).and_wrap_original do |original_method, *args|
        original_method.call(args[0], file_seed)
      end
    end

    after do
      VCR.eject_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location')
      VCR.eject_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload')
      Common::FileHelpers.delete_file_if_exists(metadata_file)
    end

    it 'bundles main form with supporting evidence for Benefits Intake' do
      main_attachment = double('MainAttachment')
      file_mock = double('file')
      allow(file_mock).to receive(:open).and_return(double(path: pdf_path.to_s))
      allow(main_attachment).to receive(:file).and_return(file_mock)
      allow(PersistentAttachment).to receive(:find_by).with(guid: main_confirmation_code).and_return(main_attachment)
      support_attachment_first = double('SupportAttachment1')
      support_attachment_second = double('SupportAttachment2')

      file_mock_first = double('file_first')
      file_mock_second = double('file_second')
      allow(file_mock_first).to receive(:open).and_return(double(path: '/tmp/support1.pdf'))
      allow(file_mock_second).to receive(:open).and_return(double(path: '/tmp/support2.pdf'))
      allow(support_attachment_first).to receive(:file).and_return(file_mock_first)
      allow(support_attachment_second).to receive(:file).and_return(file_mock_second)

      allow(PersistentAttachment).to receive(:where).with(guid: supporting_evidence_codes)
                                                    .and_return([support_attachment_first, support_attachment_second])

      pdf_stamper = double(stamp_pdf: nil)
      allow(SimpleFormsApi::PdfStamper).to receive(:new).and_return(pdf_stamper)

      lighthouse_service = double('BenefitsIntake::Service')
      allow(BenefitsIntake::Service).to receive(:new).and_return(lighthouse_service)

      allow(lighthouse_service).to receive(:request_upload).and_return(['http://upload-url', 'uuid-123'])

      expect(lighthouse_service).to receive(:perform_upload) do |args|
        expect(args[:attachments]).to be_an(Array)
        expect(args[:attachments].length).to eq(2)
        expect(args[:attachments]).to include('/tmp/support1.pdf', '/tmp/support2.pdf')
        double(status: 200)
      end

      post('/simple_forms_api/v1/submit_scanned_form', params: params_with_supporting_evidence)

      expect(response).to have_http_status(:ok)
    end

    it 'handles submission without supporting evidence (existing behavior)' do
      main_attachment = double('MainAttachment')
      file_mock = double('file')
      allow(file_mock).to receive(:open).and_return(double(path: pdf_path.to_s))
      allow(main_attachment).to receive(:file).and_return(file_mock)
      allow(PersistentAttachment).to receive(:find_by).with(guid: main_confirmation_code).and_return(main_attachment)

      allow(PersistentAttachment).to receive(:where).with(guid: []).and_return([])

      pdf_stamper = double(stamp_pdf: nil)
      allow(SimpleFormsApi::PdfStamper).to receive(:new).and_return(pdf_stamper)

      lighthouse_service = double('BenefitsIntake::Service')
      allow(BenefitsIntake::Service).to receive(:new).and_return(lighthouse_service)

      allow(lighthouse_service).to receive(:request_upload).and_return(['http://upload-url', 'uuid-123'])

      expect(lighthouse_service).to receive(:perform_upload) do |args|
        expect(args[:attachments]).to eq([])
        double(status: 200)
      end

      post('/simple_forms_api/v1/submit_scanned_form', params: base_params)

      expect(response).to have_http_status(:ok)
    end
  end
end
