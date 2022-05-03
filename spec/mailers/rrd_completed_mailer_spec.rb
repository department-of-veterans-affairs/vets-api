# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RrdCompletedMailer, type: [:mailer] do
  let(:email) do
    described_class.build(submission).deliver_now
  end

  context 'the data IS sufficient to fast track the claim' do
    let(:rrd_pdf_json) do
      { 'name' => 'VAMC_Hypertension_Rapid_Decision_Evidence.pdf',
        'confirmationCode' => 'fake_confirmation_code',
        'attachmentId' => 'L048' }
    end

    let(:bp_readings_count) { 1234 }

    let!(:submission) do
      submission = create(:form526_submission, :hypertension_claim_for_increase_with_uploads,
                          user_uuid: 'fake uuid',
                          auth_headers_json: 'fake auth headers')
      # Set the metadata like RRD processors would
      form_json = submission.form
      form_json['form526_uploads'].append(rrd_pdf_json)
      disabilities = form_json.dig('form526', 'form526', 'disabilities')
      disabilities.first['specialIssues'] = ['RRD']

      submission.save_metadata({
                                 pdf_created: true,
                                 # Set the bp_readings_count like `add_medical_stats` is expected to do
                                 med_stats: { bp_readings_count: bp_readings_count },
                                 pdf_guid: 'a950ef07-9eaa-4784-b5af-bda8c50a83f9'
                               })
      submission
    end

    it 'has the expected subject in production' do
      prior_env = Settings.vsp_environment
      Settings.vsp_environment = 'production'
      expect(email.subject).to eq 'RRD claim - 7101 - Processed'
      Settings.vsp_environment = prior_env
    end

    it 'has the expected subject in staging' do
      Settings.vsp_environment = 'staging'
      expect(email.subject).to eq '[staging] RRD claim - 7101 - Processed'
    end

    it 'has the expected content' do
      expect(email.body).to include 'Environment: '
      expect(email.body).to include 'A single-issue hypertension (7101) claim for increase was submitted on va.gov.'
      expect(email.body).to include 'A health summary PDF was generated and added to the claim\'s documentation.'
      expect(email.body).to include "Number of BP readings: #{bp_readings_count}"
      expect(email.body).to include 'PDF id in S3: a950ef07-9eaa-4784-b5af-bda8c50a83f9'
    end
  end

  context 'when the claim was offramped due to an existing EP 020' do
    let!(:submission) do
      create(:form526_submission).tap do |submission|
        submission.save_metadata(offramp_reason: 'pending_ep')
      end
    end

    it 'has the expected subject' do
      expect(email.subject).to match(/RRD claim - .* - Pending ep/)
    end

    it 'has the expected content' do
      expect(email.body).to match(/A single-issue .* claim for increase was submitted on va.gov./)
      expect(email.body)
        .to include 'There was already a pending EP 020 for the veteran associated with this claim.'
    end
  end

  context 'the data IS NOT sufficient to fast track the claim' do
    let!(:submission) do
      create(:form526_submission).tap do |submission|
        submission.save_metadata(offramp_reason: 'insufficient_data')
      end
    end

    it 'has the expected subject' do
      expect(email.subject).to match(/RRD claim - .* - Insufficient data/)
    end

    it 'has the expected content' do
      expect(email.body).to match(/A single-issue .* claim for increase was submitted on va.gov./)
      expect(email.body)
        .to include 'There was not sufficient data to generate a health summary PDF associated with this claim.'
    end
  end

  context 'an error occurred' do
    let!(:submission) do
      create(:form526_submission).tap do |submission|
        submission.save_metadata(error: 'Something bad happened')
      end
    end

    it 'has the expected subject' do
      expect(email.subject).to match(/RRD claim - .* - Error/)
    end

    it 'has the expected content' do
      expect(email.body).to include 'There was an error with this claim: Something bad happened'
    end
  end

  context 'unknown rrd_status' do
    let!(:submission) do
      create(:form526_submission).tap do |submission|
        submission.save_metadata(something_useful: 'Unknown status')
      end
    end

    it 'has the expected subject' do
      expect(email.subject).to match(/RRD claim - .* - Unknown/)
    end

    it 'has the expected content' do
      expect(email.body).to include 'Metadata: {"something_useful"=>"Unknown status"}'
    end
  end
end
