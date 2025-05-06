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
    let(:confirmation_code) { '123456' }
    let(:attachment) { double }

    before do
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
      expect(PersistentAttachment).to receive(:find_by).with(guid: confirmation_code).and_return(attachment)

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
end
