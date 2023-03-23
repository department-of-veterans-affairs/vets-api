# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RrdCompletedMailer, type: [:mailer] do
  let(:email) do
    described_class.build(submission).deliver_now
  end

  def simulate_rrd_results(submission, metadata = {})
    # Set the metadata like RRD processors would
    form_json = submission.form
    form_json['form526_uploads'].append(rrd_pdf_json)
    disabilities = form_json.dig('form526', 'form526', 'disabilities')
    disabilities.first['specialIssues'] = ['RRD']

    submission.save_metadata(metadata)
    submission
  end

  context 'the data IS sufficient to fast track the claim' do
    let(:rrd_pdf_json) do
      { 'name' => 'VAMC_Hypertension_Rapid_Decision_Evidence.pdf',
        'confirmationCode' => 'fake_confirmation_code',
        'attachmentId' => 'L048' }
    end

    let(:bp_readings_count) { 1234 }

    let(:active_medications_count) { 1111 }

    let!(:submission) do
      submission = create(:form526_submission, :hypertension_claim_for_increase_with_uploads,
                          user_uuid: 'fake uuid',
                          auth_headers_json: 'fake auth headers')

      simulate_rrd_results(submission, {
                             pdf_created: true,
                             med_stats: { bp_readings_count:,
                                          medications_count: active_medications_count },
                             pdf_guid: 'a950ef07-9eaa-4784-b5af-bda8c50a83f9'
                           })
    end

    context 'when vsp_environment is production' do
      let(:environment) { 'production' }

      before do
        allow(Settings).to receive(:vsp_environment).and_return(environment)
      end

      it 'has the expected subject' do
        expect(email.subject).to eq 'RRD claim - 7101 - Processed'
      end
    end

    context 'when vsp_environment is staging' do
      let(:environment) { 'staging' }

      before do
        allow(Settings).to receive(:vsp_environment).and_return(environment)
      end

      it 'has the expected subject' do
        expect(email.subject).to eq '[staging] RRD claim - 7101 - Processed'
      end
    end

    it 'has the expected content' do
      expect(email.body).to include 'Environment: '
      expect(email.body).to include 'A single-issue hypertension (7101) claim for increase was submitted on va.gov.'
      expect(email.body).to include 'A health summary PDF was generated and added to the claim\'s documentation.'
      expect(email.body).to include "Number of BP readings: #{bp_readings_count}"
      expect(email.body).to include "Number of Active Medications: #{active_medications_count}"
      expect(email.body).to include 'PDF id in S3: a950ef07-9eaa-4784-b5af-bda8c50a83f9'
    end

    context 'when the claim is for asthma' do
      let(:rrd_pdf_json) do
        { 'name' => 'VAMC_Asthma_Rapid_Decision_Evidence.pdf',
          'confirmationCode' => 'fake_confirmation_code',
          'attachmentId' => 'L048' }
      end

      let(:asthma_medications_count) { 4444 }

      let!(:submission) do
        submission = create(:form526_submission, :asthma_claim_for_increase_with_uploads,
                            user_uuid: 'fake uuid',
                            auth_headers_json: 'fake auth headers')

        simulate_rrd_results(submission, {
                               pdf_created: true,
                               med_stats: { medications_count: active_medications_count,
                                            asthma_medications_count: },
                               pdf_guid: 'a950ef07-9eaa-4784-b5af-bda8c50a83f9'
                             })
      end

      it 'has the expected content' do
        expect(email.body).to include 'Environment: '
        expect(email.body).to include 'A single-issue asthma (6602) claim for increase was submitted on va.gov.'
        expect(email.body).to include 'A health summary PDF was generated and added to the claim\'s documentation.'
        expect(email.body).to include 'Number of BP readings: N/A'
        expect(email.body).to include 'PDF id in S3: a950ef07-9eaa-4784-b5af-bda8c50a83f9'
        expect(email.body).to include 'Number of BP readings: N/A'
        expect(email.body).to include "Number of Asthma Medications: #{asthma_medications_count}"
        expect(email.body).to include "Number of Active Medications: #{active_medications_count}"
      end
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
