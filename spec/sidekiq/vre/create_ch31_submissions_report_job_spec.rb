# frozen_string_literal: true

require 'rails_helper'

describe VRE::CreateCh31SubmissionsReportJob do
  let(:zone) { 'Eastern Time (US & Canada)' }
  let(:time) { ActiveSupport::TimeZone[zone].parse('2021-11-15 00:00:00') }

  let(:vre_claim1) do
    Timecop.freeze(time) { create(:veteran_readiness_employment_claim, regional_office: '377 - San Diego') }
  end

  let(:vre_claim2) do
    Timecop.freeze(time) { create(:veteran_readiness_employment_claim, regional_office: '349 - Waco') }
  end

  let(:vre_claim3) do
    Timecop.freeze(time) { create(:veteran_readiness_employment_claim, regional_office: '351 - Muskogee') }
  end

  let(:vre_claim4) do
    Timecop.freeze(time) { create(:veteran_readiness_employment_claim, regional_office: '377 - San Diego') }
  end

  let(:vre_claim5) do
    Timecop.freeze(time) { create(:veteran_readiness_employment_claim, regional_office: '349 - Waco') }
  end

  let(:vre_claim6) do
    Timecop.freeze(time) { create(:veteran_readiness_employment_claim, regional_office: '351 - Muskogee') }
  end

  describe 'raises an exception' do
    it 'when queue is exhausted' do
      VRE::CreateCh31SubmissionsReportJob.within_sidekiq_retries_exhausted_block do
        expect(Rails.logger).to receive(:error).exactly(:once).with(
          'Failed all retries on VRE::CreateCh31SubmissionsReportJob, last error: An error occurred'
        )
        expect(StatsD).to receive(:increment).with('worker.vre.create_ch31_submissions_report_job.exhausted')
      end
    end
  end

  describe '#perform' do
    subject { described_class.new.perform(sidekiq_scheduler_args, specific_date) }

    before do
      expect(Ch31SubmissionsReportMailer).to receive(:build).with(submitted_claims).and_call_original
      expect(FeatureFlipper).to receive(:staging_email?).once.and_return(false)
    end

    # context 'passed sidekiq_scheduler_args' do
    #   let(:sidekiq_scheduler_args) { { 'scheduled_at' => Time.zone.now.to_i } }
    #   let(:specific_date) { nil }
    #   let(:submitted_claims) { [vre_claim2, vre_claim3, vre_claim1] }

    #   it 'sparks mailer with claims sorted by Regional Office' do
    #     Timecop.freeze(ActiveSupport::TimeZone[zone].parse('2021-11-16 00:00:01')) { subject }
    #   end

    #   it 'does not send if FeatureFlipper.staging_email?  is true' do
    #     RSpec::Mocks.space.proxy_for(Ch31SubmissionsReportMailer).reset
    #     RSpec::Mocks.space.proxy_for(FeatureFlipper).reset
    #     expect(FeatureFlipper).to receive(:staging_email?).once.and_return(true)
    #     expect(Ch31SubmissionsReportMailer).not_to receive(:build).with(submitted_claims)
    #     subject
    #   end
    # end

    context 'passed specific date in YYYY-MM-DD format' do
      let(:sidekiq_scheduler_args) { {} }
      let(:specific_date) { '2021-11-15' }
      let(:submitted_claims) { [vre_claim5, vre_claim6, vre_claim4] }

      it 'sparks mailer with claims sorted by Regional Office' do
        subject
      end

      it 'does not send if FeatureFlipper.staging_email? is true' do
        RSpec::Mocks.space.proxy_for(Ch31SubmissionsReportMailer).reset
        RSpec::Mocks.space.proxy_for(FeatureFlipper).reset
        expect(FeatureFlipper).to receive(:staging_email?).once.and_return(true)
        expect(Ch31SubmissionsReportMailer).not_to receive(:build).with(submitted_claims)
        subject
      end
    end
  end
end
