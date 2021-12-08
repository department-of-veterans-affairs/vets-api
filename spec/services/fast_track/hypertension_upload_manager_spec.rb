# frozen_string_literal: true

require 'rails_helper'
require 'fast_track/disability_compensation_job'

RSpec.describe FastTrack::HypertensionUploadManager do
  let(:user) { create(:disabilities_compensation_user) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:saved_claim) { FactoryBot.create(:va526ez) }
  let(:original_form_json) do
    File.read('spec/support/disability_compensation_form/submissions/with_uploads.json')
  end

  let(:original_form_json_uploads) do
    JSON.parse(original_form_json)['form526_uploads']
  end

  let(:form526_submission) do
    Form526Submission.create(
      user_uuid: user.uuid,
      saved_claim_id: saved_claim.id,
      auth_headers_json: auth_headers.to_json,
      form_json: original_form_json
    )
  end

  describe '#add_upload(confirmation_code)' do
    context 'success' do
      it 'appends the new upload and saves the expected JSON' do
        FastTrack::HypertensionUploadManager.new(form526_submission).add_upload('fake_confirmation_code')
        parsed_json = JSON.parse(form526_submission.form_json)['form526_uploads']
        expect(parsed_json).to match original_form_json_uploads + [
          { 'name' => 'VAMC_Hypertension_Rapid_Decision_Evidence.pdf',
            'confirmationCode' => 'fake_confirmation_code',
            'attachmentId' => '1489' }
        ]
      end

      context 'there are no existing uploads present in the list' do
        let(:original_form_json) do
          File.read('spec/support/disability_compensation_form/submissions/without_form526_uploads.json')
        end

        it 'adds the new upload' do
          FastTrack::HypertensionUploadManager.new(form526_submission).add_upload('fake_confirmation_code')
          parsed_json = JSON.parse(form526_submission.form_json)['form526_uploads']

          expect(parsed_json).to match [
            { 'name' => 'VAMC_Hypertension_Rapid_Decision_Evidence.pdf',
              'confirmationCode' => 'fake_confirmation_code',
              'attachmentId' => '1489' }
          ]
        end
      end
    end
  end

  describe '#already_has_summary_files' do
    context 'success' do
      it 'returns false if no summary file is present' do
        expect(FastTrack::HypertensionUploadManager.new(form526_submission).already_has_summary_file).to eq false
      end

      it 'returns true after a summary file is added' do
        FastTrack::HypertensionUploadManager.new(form526_submission).add_upload('fake_confirmation_code')
        expect(FastTrack::HypertensionUploadManager.new(form526_submission).already_has_summary_file).to eq true
      end
    end
  end

  describe '#handle_attachment' do
    it 'does NOT create a new SupportingEvidenceAttachment' do
      # add file once to test trying to add it again
      FastTrack::HypertensionUploadManager.new(form526_submission).add_upload('fake_confirmation_code')

      expect do
        FastTrack::HypertensionUploadManager.new(form526_submission).handle_attachment('fake file')
      end.not_to change(
        SupportingEvidenceAttachment, :count
      )
    end

    it 'creates a new SupportingEvidenceAttachment' do
      expect do
        FastTrack::HypertensionUploadManager.new(form526_submission).handle_attachment('fake file')
      end.to change(
        SupportingEvidenceAttachment, :count
      ).by 1
    end
  end
end
