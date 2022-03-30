# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RrdCompletedMailer, type: [:mailer] do
  let(:email) do
    described_class.build(submission).deliver_now
  end

  context 'the data IS sufficient to fast track the claim' do
    let(:form_json) do
      File.read('spec/support/disability_compensation_form/submissions/with_uploads.json')
    end

    let(:rrd_pdf_json) do
      { 'name' => 'VAMC_Hypertension_Rapid_Decision_Evidence.pdf',
        'confirmationCode' => 'fake_confirmation_code',
        'attachmentId' => 'L048' }
    end

    let(:saved_claim) { FactoryBot.create(:va526ez) }
    let(:bp_readings_count) { 1234 }

    let!(:submission) do
      submission = create(:form526_submission, :with_uploads, user_uuid: 'fake uuid',
                                                              auth_headers_json: 'fake auth headers',
                                                              saved_claim_id: saved_claim.id,
                                                              form_json: form_json)
      # Set the bp_readings_count like `add_medical_stats` is expected to do
      form_json = JSON.parse(submission.form_json)
      form_json['rrd_metadata'] = { med_stats: { bp_readings_count: bp_readings_count } }
      form_json['form526_uploads'].append(rrd_pdf_json)
      submission.update!(form_json: JSON.dump(form_json))
      submission.invalidate_form_hash
      submission
    end

    it 'has the expected subject' do
      expect(email.subject).to start_with 'RRD claim - Processed'
    end

    it 'has the expected content' do
      expect(email.body).to include 'A single-issue 5235 claim for increase was submitted on va.gov.'
      expect(email.body).to include 'A health summary PDF was generated and added to the claim\'s documentation.'
      expect(email.body).to include "<td>#{bp_readings_count}</td>"
    end
  end

  context 'when the claim was offramped due to an existing EP 020' do
    let!(:submission) do
      submission = create(:form526_submission, :with_uploads, user_uuid: 'fake uuid',
                                                              auth_headers_json: 'fake auth headers')
      RapidReadyForDecision::Form526BaseJob.add_metadata(submission, offramp_reason: 'pending_ep')
      submission
    end

    it 'has the expected subject' do
      expect(email.subject).to start_with 'RRD claim - Pending ep'
    end

    it 'has the expected content' do
      expect(email.body).to include 'A single-issue 5235 claim for increase was submitted on va.gov.'
      expect(email.body)
        .to include 'There was already a pending EP 020 for the veteran associated with this claim.'
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
      expect(email.subject).to start_with 'RRD claim - Insufficient data'
    end

    it 'has the expected content' do
      expect(email.body).to include 'A single-issue 5235 claim for increase was submitted on va.gov.'
      expect(email.body)
        .to include 'There was not sufficient data to generate a health summary PDF associated with this claim.'
    end
  end
end
