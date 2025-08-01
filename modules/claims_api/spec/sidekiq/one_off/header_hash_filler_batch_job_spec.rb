# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/filler'

RSpec.describe ClaimsApi::OneOff::HeaderHashFillerBatchJob, type: :job do
  subject { described_class.new }

  before do
    Timecop.freeze(1.year.ago) do
      create_list(:power_of_attorney, 10)
      ClaimsApi::PowerOfAttorney.update_all(header_hash: nil) # rubocop:disable Rails/SkipsModelValidations
      create_list(:auto_established_claim, 10)
      ClaimsApi::AutoEstablishedClaim.update_all(header_hash: nil) # rubocop:disable Rails/SkipsModelValidations
    end
    allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_run_header_hash_filler_job).and_return true
  end

  describe '#perform' do
    it 'enqueues jobs for filling header_hash in batches' do
      expect_any_instance_of(described_class).to receive(:enqueue_jobs).twice
      subject.perform
    end

    it 'skips processing if the feature flag is disabled' do
      allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_run_header_hash_filler_job).and_return false
      expect_any_instance_of(described_class).not_to receive(:enqueue_jobs)
      expect_any_instance_of(described_class).to receive(:log)
      subject.perform
    end

    context 'when no records need processing' do
      it 'skips processing and alerts' do
        ClaimsApi::PowerOfAttorney.update_all(header_hash: 'some_value') # rubocop:disable Rails/SkipsModelValidations
        ClaimsApi::AutoEstablishedClaim.update_all(header_hash: 'some_value') # rubocop:disable Rails/SkipsModelValidations

        expect_any_instance_of(described_class).not_to receive(:enqueue_jobs)
        expect_any_instance_of(SlackNotify::Client).to receive(:notify)
        subject.perform
      end
    end
  end

  describe '#enqueue_jobs' do
    it 'enqueues jobs for filling header_hash in batches' do
      expect(ClaimsApi::OneOff::HeaderHashFillerJob).to receive(:perform_in).exactly(3).times
      subject.enqueue_jobs('ClaimsApi::PowerOfAttorney', 1_501)
    end

    it 'limits the number of batches to 10' do
      expect(ClaimsApi::OneOff::HeaderHashFillerJob).to receive(:perform_in).exactly(10).times
      subject.enqueue_jobs('ClaimsApi::PowerOfAttorney', 100_000)
    end
  end
end
