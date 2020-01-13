# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MHV::AccountStatisticsJob, type: :job do
  describe 'AccountStatisticsJob' do
    it 'increments the StatsD.gauge for each statistic' do
      allow(StatsD).to receive(:gauge)

      MHV::AccountStatisticsJob.new.perform

      expect(StatsD).to have_received(:gauge).with('mhv.account.created_count', 0).exactly(1).time
      expect(StatsD).to have_received(:gauge).with('mhv.account.existing_premium_count', 0).exactly(1).time
      expect(StatsD).to have_received(:gauge).with('mhv.account.existing_upgraded_count', 0).exactly(1).time
      expect(StatsD).to have_received(:gauge).with('mhv.account.existing_failed_upgrade_count', 0).exactly(1).time
      expect(StatsD).to have_received(:gauge).with('mhv.account.created_premium_count', 0).exactly(1).time
      expect(StatsD).to have_received(:gauge).with('mhv.account.created_failed_upgrade_count', 0).exactly(1).time
      expect(StatsD).to have_received(:gauge).with('mhv.account.created_and_upgraded_count', 0).exactly(1).time
      expect(StatsD).to have_received(:gauge).with('mhv.account.failed_create_count', 0).exactly(1).time
      expect(StatsD).to have_received(:gauge).with('mhv.account.total_count', 0).exactly(1).time
      expect(StatsD).to have_received(:gauge).with('mhv.account.active.created_count', 0).exactly(1).time
      expect(StatsD).to have_received(:gauge).with('mhv.account.active.existing_premium_count', 0).exactly(1).time
      expect(StatsD).to have_received(:gauge).with('mhv.account.active.existing_upgraded_count', 0).exactly(1).time
      expect(StatsD).to have_received(:gauge).with('mhv.account.active.existing_failed_upgrade_count', 0).exactly(1).time
      expect(StatsD).to have_received(:gauge).with('mhv.account.active.created_premium_count', 0).exactly(1).time
      expect(StatsD).to have_received(:gauge).with('mhv.account.active.created_failed_upgrade_count', 0).exactly(1).time
      expect(StatsD).to have_received(:gauge).with('mhv.account.active.created_and_upgraded_count', 0).exactly(1).time
      expect(StatsD).to have_received(:gauge).with('mhv.account.active.failed_create_count', 0).exactly(1).time
      expect(StatsD).to have_received(:gauge).with('mhv.account.active.total_count', 0).exactly(1).time
    end
  end
end
