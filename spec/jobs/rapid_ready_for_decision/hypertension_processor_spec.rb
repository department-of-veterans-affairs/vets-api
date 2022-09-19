# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe RapidReadyForDecision::HypertensionProcessor do
  around do |example|
    VCR.use_cassette('evss/claims/claims_without_open_compensation_claims') do
      VCR.use_cassette('rrd/hypertension', &example)
    end
  end

  before { Flipper.disable(:rrd_call_vro_service) }

  let(:submission) do
    create(:form526_submission, :hypertension_claim_for_increase)
  end

  let(:mocked_observation_data) do
    [{ effectiveDateTime: "#{Time.zone.today.year}-06-21T02:42:52Z",
       practitioner: 'DR. THOMAS359 REYNOLDS206 PHD',
       organization: 'LYONS VA MEDICAL CENTER',
       systolic: { 'code' => '8480-6', 'display' => 'Systolic blood pressure', 'value' => 115.0,
                   'unit' => 'mm[Hg]' },
       diastolic: { 'code' => '8462-4', 'display' => 'Diastolic blood pressure', 'value' => 87.0,
                    'unit' => 'mm[Hg]' } }]
  end

  describe '#perform' do
    before do
      # The bp reading needs to be 1 year or less old so actual API data will not test if this code is working.
      allow_any_instance_of(RapidReadyForDecision::LighthouseObservationData)
        .to receive(:transform).and_return(mocked_observation_data)
    end

    let(:rrd_sidekiq_job) { RapidReadyForDecision::Constants::DISABILITIES[:hypertension][:sidekiq_job] }

    it 'finishes successfully' do
      Sidekiq::Testing.inline! do
        rrd_sidekiq_job.constantize.perform_async(submission.id)

        submission.reload
        expect(submission.form.dig('rrd_metadata', 'med_stats', 'bp_readings_count')).to eq 1
      end
    end

    it 'adds a special issue to the submission' do
      expect_any_instance_of(RapidReadyForDecision::RrdSpecialIssueManager).to receive(:add_special_issue)

      Sidekiq::Testing.inline! do
        RapidReadyForDecision::Form526BaseJob.perform_async(submission.id)
      end
    end

    context 'when no data from Lighthouse' do
      before do
        allow_any_instance_of(Lighthouse::VeteransHealth::Client).to receive(:list_bp_observations).and_return([])
      end

      it 'finishes with offramp_reason: insufficient_data' do
        Sidekiq::Testing.inline! do
          rrd_sidekiq_job.constantize.perform_async(submission.id)

          submission.reload
          expect(submission.form.dig('rrd_metadata', 'offramp_reason')).to eq 'insufficient_data'
        end
      end
    end
  end
end
