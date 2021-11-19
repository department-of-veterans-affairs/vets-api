# frozen_string_literal: true

require 'rails_helper'

describe VRE::CreateCh31SubmissionsReport do
  let!(:vre_claim1) do
    create :veteran_readiness_employment_claim, regional_office: '377 - San Diego', created_at: Time.zone.now.yesterday
  end
  let!(:vre_claim2) do
    create :veteran_readiness_employment_claim, regional_office: '349 - Waco', created_at: Time.zone.now.yesterday
  end
  let!(:vre_claim3) do
    create :veteran_readiness_employment_claim, regional_office: '351 - Muskogee', created_at: Time.zone.now.yesterday
  end
  let!(:vre_claim4) do
    create :veteran_readiness_employment_claim, regional_office: '377 - San Diego',
                                                created_at: '2021-11-15 11:59:59 -0500'
  end
  let!(:vre_claim5) do
    create :veteran_readiness_employment_claim, regional_office: '349 - Waco', created_at: '2021-11-15 11:59:59 -0500'
  end
  let!(:vre_claim6) do
    create :veteran_readiness_employment_claim, regional_office: '351 - Muskogee',
                                                created_at: '2021-11-15 11:59:59 -0500'
  end

  describe '#perform' do
    context 'passed sidekiq_scheduler_args' do
      it 'sparks mailer with claims sorted by Regional Office' do
        submitted_claims = [vre_claim2, vre_claim3, vre_claim1]
        sidekiq_scheduler_args = { 'scheduled_at' => Time.zone.now.to_i }
        expect(Ch31SubmissionsReportMailer).to receive(:build).with(submitted_claims).and_call_original
        described_class.new.perform(sidekiq_scheduler_args)
      end
    end

    context 'passed specific date in YYYY-MM-DD format' do
      it 'sparks mailer with claims sorted by Regional Office' do
        submitted_claims = [vre_claim5, vre_claim6, vre_claim4]
        specific_date = '2021-11-15'
        expect(Ch31SubmissionsReportMailer).to receive(:build).with(submitted_claims).and_call_original
        described_class.new.perform({}, specific_date)
      end
    end
  end
end
