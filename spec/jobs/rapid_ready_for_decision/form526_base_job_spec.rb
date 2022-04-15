# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe RapidReadyForDecision::Form526BaseJob, type: :worker do
  before { Sidekiq::Worker.clear_all }

  let!(:user) { FactoryBot.create(:disabilities_compensation_user, icn: '2000163') }
  let(:submission) { create(:form526_submission, :with_uploads, user: user, submitted_claim_id: '600130094') }

  let(:mocked_observation_data) do
    [{ effectiveDateTime: "#{Time.zone.today.year}-06-21T02:42:52Z",
       practitioner: 'DR. THOMAS359 REYNOLDS206 PHD',
       organization: 'LYONS VA MEDICAL CENTER',
       systolic: { 'code' => '8480-6', 'display' => 'Systolic BP', 'value' => 115.0, 'unit' => 'mm[Hg]' },
       diastolic: { 'code' => '8462-4', 'display' => 'Diastolic BP', 'value' => 87.0, 'unit' => 'mm[Hg]' } }]
  end

  describe '#perform', :vcr do
    around do |example|
      VCR.use_cassette('evss/claims/claims_without_open_compensation_claims', &example)
    end

    context 'the claim is NOT for hypertension' do
      let(:icn_for_user_without_bp_reading_within_one_year) { 17_000_151 }
      let!(:user) do
        FactoryBot.create(:disabilities_compensation_user, icn: icn_for_user_without_bp_reading_within_one_year)
      end
      let!(:submission_for_user_wo_bp) do
        create(:form526_submission, :with_uploads, user: user, submitted_claim_id: '600130094')
      end

      it 'raises NoRrdProcessorForClaim' do
        Sidekiq::Testing.inline! do
          expect { described_class.perform_async(submission_for_user_wo_bp.id) }
            .to raise_error described_class::NoRrdProcessorForClaim
        end
      end
    end
  end
end
