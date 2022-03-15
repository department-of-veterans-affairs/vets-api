# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HypertensionFastTrackPilotMailer, type: [:mailer] do
  let(:email) do
    described_class.build(submission).deliver_now
  end

  context 'the data IS sufficient to fast track the claim' do
    let(:form_json) do
      File.read('spec/support/disability_compensation_form/submissions/with_uploads.json')
    end

    let(:pdf_json_string) do
      { 'name' => 'VAMC_Hypertension_Rapid_Decision_Evidence.pdf',
        'confirmationCode' => 'fake_confirmation_code',
        'attachmentId' => 'L023' }.to_s
    end

    let(:saved_claim) { FactoryBot.create(:va526ez) }

    let!(:submission) do
      create(:form526_submission, :with_uploads, user_uuid: 'fake uuid',
                                                 auth_headers_json: 'fake auth headers',
                                                 saved_claim_id: saved_claim.id,
                                                 form_json: form_json + pdf_json_string)
    end

    it 'has the expected subject' do
      expect(email.subject).to eq 'RRD claim - Processed'
    end

    it 'has the expected content' do
      expect(email.body).to include 'A single-issue hypertension claim for increase was submitted on va.gov.'
      expect(email.body).to include 'A health summary PDF was generated and added to the claim\'s documentation.'
    end
  end

  context 'the data IS NOT sufficient to fast track the claim' do
    let(:form_json) do
      File.read('spec/support/disability_compensation_form/submissions/with_uploads.json')
    end

    let(:saved_claim) { FactoryBot.create(:va526ez) }

    let!(:submission) do
      create(:form526_submission, :with_uploads, user_uuid: 'fake uuid',
                                                 auth_headers_json: 'fake auth headers',
                                                 saved_claim_id: saved_claim.id,
                                                 form_json: form_json)
    end

    it 'has the expected subject' do
      expect(email.subject).to eq 'RRD claim - Insufficient Data'
    end

    it 'has the expected content' do
      expect(email.body).to include 'A single-issue hypertension claim for increase was submitted on va.gov.'
      expect(email.body)
        .to include 'There was not sufficient data to generate a health summary PDF associated with this claim.'
    end
  end
end
