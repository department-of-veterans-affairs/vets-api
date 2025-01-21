# frozen_string_literal: true

require 'rails_helper'
require 'timecop'

describe Vye::SundownSweep::PurgeStaleVerifications, type: :worker do
  before do
    Sidekiq::Job.clear_all
  end

  context 'when it is not a holiday' do
    before do
      Timecop.freeze(Time.zone.local(2024, 7, 2)) # Regular work day
    end

    after do
      Timecop.return
    end

    it 'checks the existence of described_class' do
      expect do
        described_class.perform_async
      end.to change { Sidekiq::Worker.jobs.size }.by(1)

      described_class.drain
    end

    it 'purges (deletes) stale verifications (created over 5 years ago)' do
      create(:vye_verification)
      create(:vye_verification, :stale)

      expect(Vye::Verification.count).to eq(2)
      expect { described_class.new.perform }.to change(Vye::Verification, :count).by(-1)
      expect(Vye::Verification.count).to eq(1)
    end
  end
end
