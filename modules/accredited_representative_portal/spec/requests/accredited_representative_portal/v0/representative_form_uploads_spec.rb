# frozen_string_literal: true

require_relative '../../../rails_helper'
require 'simple_forms_api_submission/metadata_validator'
require 'common/file_helpers'

RSpec.describe AccreditedRepresentativePortal::V0::RepresentativeFormUploadController, type: :request do
  let(:representative_user) { create(:representative_user) }
  let(:form_number) { '21-686c' }

  before do
    login_as(representative_user)
  end

  describe '#submit' do
    let(:representative_fixture_path) do
      Rails.root.join('modules', 'accredited_representative_portal', 'spec', 'fixtures', 'form_data',
                      'representative_form_upload_21_686c.json')
    end
    let(:veteran_params) { JSON.parse(representative_fixture_path.read) }

    let(:claimant_fixture_path) do
      Rails.root.join('modules', 'accredited_representative_portal', 'spec', 'fixtures', 'form_data',
                      'claimant_form_upload_21_686c.json')
    end
    let(:claimant_params) { JSON.parse(claimant_fixture_path.read) }
    let(:form_name) { 'Request for Nursing Home Information in Connection with Claim for Aid and Attendance' }
    let(:metadata_file) { "#{file_seed}.SimpleFormsApi.metadata.json" }
    let(:file_seed) { 'tmp/some-unique-simple-forms-file-seed' }
    let(:random_string) { 'some-unique-simple-forms-file-seed' }
    let(:pdf_path) do
      Rails.root.join('modules', 'accredited_representative_portal', 'spec', 'fixtures', 'files',
                      '21_686c_empty_form.pdf')
    end
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

    it 'makes the veteran request' do
      expect(PersistentAttachment).to receive(:find_by).with(guid: confirmation_code).and_return(attachment)
      post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)

      expect(response).to have_http_status(:ok)
    end

    it 'makes the claimant request' do
      expect(PersistentAttachment).to receive(:find_by).with(guid: confirmation_code).and_return(attachment)
      post('/accredited_representative_portal/v0/submit_representative_form', params: claimant_params)

      expect(response).to have_http_status(:ok)
    end

    it 'stamps the pdf' do
      expect(pdf_stamper).to receive(:stamp_pdf)

      post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)

      expect(response).to have_http_status(:ok)
    end

    it 'saves the FormSubmission and FormSubmissionAttempt' do
      form_submission = double
      expect(FormSubmission).to receive(:create).with(
        form_type: form_number,
        form_data: veteran_params['representative_form_upload']['formData'].to_json,
        user_account: representative_user.user_account
      ).and_return(form_submission)
      expect(FormSubmissionAttempt).to receive(:create).with(
        form_submission:,
        benefits_intake_uuid: anything
      )

      post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)

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
        post '/accredited_representative_portal/v0/representative_form_upload', params:
      end.to change(PersistentAttachment, :count).by(1)

      expect(response).to have_http_status(:ok)
      resp = JSON.parse(response.body)
      expect(resp['data']['attributes'].keys.sort).to eq(%w[confirmationCode name size warnings])
      expect(PersistentAttachment.last).to be_a(PersistentAttachments::VAForm)
    end
  end
end
