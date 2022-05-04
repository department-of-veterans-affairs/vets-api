# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe RapidReadyForDecision::AsthmaProcessor do
  around do |example|
    VCR.use_cassette('evss/claims/claims_without_open_compensation_claims') do
      VCR.use_cassette('rrd/asthma', &example)
    end
  end

  let(:submission) { create(:form526_submission, :asthma_claim_for_increase) }
  let(:processor) { described_class.new(submission) }

  describe '#perform' do
    it 'finishes successfully' do
      Sidekiq::Testing.inline! do
        rrd_sidekiq_job = RapidReadyForDecision::Constants::DISABILITIES[:asthma][:sidekiq_job]
        rrd_sidekiq_job.constantize.perform_async(submission.id)

        submission.reload
        expect(submission.form.dig('rrd_metadata', 'pdf_guid').length).to be > 20
      end
    end
  end

  describe '#assess_data' do
    subject { processor.assess_data }

    let(:assessed_meds) { processor.claim_context.assessed_data[:medications] }

    context 'when there are active medication requests' do
      it 'returns the active medication requests' do
        subject
        expect(assessed_meds.count).to eq(11)
      end
    end

    it 'flags potential asthma-related medication' do
      subject
      expect(assessed_meds.select { |med| med[:flagged] }.count).to eq(3)
    end

    it 'correctly orders potential asthma-related medication to appear first' do
      subject
      expect(assessed_meds.take(3).all? { |med| med[:flagged] }).to eq true
    end
  end

  describe '#release_pdf?' do
    subject { processor.release_pdf? }

    it 'returns false when Flipper symbol is disabled' do
      Flipper.disable(:rrd_asthma_release_pdf)
      expect(subject).to eq false
    end

    it 'returns true when Flipper symbol is enabled' do
      Flipper.enable(:rrd_asthma_release_pdf)
      expect(subject).to eq true
    end
  end
end
