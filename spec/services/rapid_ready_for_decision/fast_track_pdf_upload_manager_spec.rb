# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RapidReadyForDecision::FastTrackPdfUploadManager do
  let(:form526_submission) { create(:form526_submission, :hypertension_claim_for_increase_with_uploads) }
  let(:claim_context) { RapidReadyForDecision::ClaimContext.new(form526_submission) }
  let(:metadata_hash) { claim_context.metadata_hash }
  let(:manager) { RapidReadyForDecision::FastTrackPdfUploadManager.new(claim_context) }

  let(:time_freeze_time) { Time.zone.parse('2021-10-10') }

  before do
    Timecop.freeze(time_freeze_time)
  end

  after do
    Timecop.return
  end

  describe '#add_upload(confirmation_code)' do
    context 'success' do
      let(:original_form_json_uploads) do
        submission_with_uploads = File.read('spec/support/disability_compensation_form/submissions/with_uploads.json')
        JSON.parse(submission_with_uploads)['form526_uploads']
      end

      it 'appends the new upload and saves the expected JSON' do
        manager.add_upload('fake_confirmation_code')
        parsed_json = JSON.parse(form526_submission.form_json)['form526_uploads']

        expect(parsed_json).to match original_form_json_uploads + [
          { 'name' => 'VAMC_Hypertension_Rapid_Decision_Evidence-20211010.pdf',
            'confirmationCode' => 'fake_confirmation_code',
            'attachmentId' => 'L1489' }
        ]
      end

      context 'there are no existing uploads present in the list' do
        let(:form526_submission) { create(:form526_submission, :hypertension_claim_for_increase) }

        it 'adds the new upload' do
          manager.add_upload('fake_confirmation_code')
          parsed_json = JSON.parse(form526_submission.form_json)['form526_uploads']

          expect(parsed_json).to match [
            { 'name' => 'VAMC_Hypertension_Rapid_Decision_Evidence-20211010.pdf',
              'confirmationCode' => 'fake_confirmation_code',
              'attachmentId' => 'L1489' }
          ]
        end
      end
    end
  end

  describe 'rrd_pdf_added_for_uploading?' do
    context 'success' do
      it 'returns false if no summary file is present' do
        expect(form526_submission.rrd_pdf_added_for_uploading?).to eq false
      end

      it 'returns true after a summary file is added' do
        manager.add_upload('fake_confirmation_code')
        expect(form526_submission.rrd_pdf_added_for_uploading?).to eq true
      end
    end
  end

  describe '#handle_attachment' do
    it 'does NOT create a new SupportingEvidenceAttachment' do
      # add file once to test trying to add it again
      manager.add_upload('fake_confirmation_code')

      expect do
        RapidReadyForDecision::FastTrackPdfUploadManager.new(claim_context).handle_attachment('fake file')
      end.not_to change(
        SupportingEvidenceAttachment, :count
      )
    end

    it 'creates a new SupportingEvidenceAttachment' do
      expect do
        manager.handle_attachment('fake file')
      end.to change(
        SupportingEvidenceAttachment, :count
      ).by 1
      expect(metadata_hash[:pdf_guid]).not_to be nil
    end

    it 'skips updating the submission when add_to_submission is false' do
      expect do
        manager.handle_attachment('fake file', add_to_submission: false)
      end.not_to change { form526_submission.form_json['form526_uploads'] }
    end
  end
end
