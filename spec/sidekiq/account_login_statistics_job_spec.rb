# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountLoginStatisticsJob, type: :job do
  describe '#perform' do
    before { allow(StatsD).to receive(:gauge) }

    it 'sets StatsD gauge for each count' do
      AccountLoginStatisticsJob.new.perform

      expect(StatsD).to have_received(:gauge)
        .with('account_login_stats.total_idme_accounts', 0).exactly(1).time
      expect(StatsD).to have_received(:gauge)
        .with('account_login_stats.total_myhealthevet_accounts', 0).exactly(1).time
      expect(StatsD).to have_received(:gauge)
        .with('account_login_stats.total_dslogon_accounts', 0).exactly(1).time
    end

    context 'with data' do
      let(:account) { create(:account) }

      before { AccountLoginStat.create(account_id: account.id, idme_at: 3.days.ago) }

      it 'finds correct total counts' do
        AccountLoginStatisticsJob.new.perform

        expect(StatsD).to have_received(:gauge)
          .with('account_login_stats.total_idme_accounts', 1).exactly(1).time
        expect(StatsD).to have_received(:gauge)
          .with('account_login_stats.total_myhealthevet_accounts', 0).exactly(1).time
        expect(StatsD).to have_received(:gauge)
          .with('account_login_stats.total_dslogon_accounts', 0).exactly(1).time
      end
    end
  end
end
