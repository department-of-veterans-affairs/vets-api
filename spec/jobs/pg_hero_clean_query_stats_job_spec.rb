# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PgHeroCleanQueryStatsJob, type: :worker do
  subject { described_class.new }

  describe '#perform' do
    let(:query_stat_count) { PgHero::QueryStats.count }
    let(:old_query_stat_count) { PgHero::QueryStats.where('captured_at < ?', 14.days.ago).count }

    context 'when it runs the query stat task' do
      it 'deletes old records' do
        subject.perform
        expect(old_query_stat_count).to eq(0)
      end

      # cleanup
      context 'when error occurs' do
        before do
          allow(PgHero).to receive(:clean_query_stats).and_raise(PgHero::Error)
        end

        it 'raises an exception when an error occurs' do
          with_settings(Settings.sentry, dsn: 'T') do
            expect(Raven).to receive(:capture_exception)
            expect(Rails.logger).to receive(:error).at_least(:once)
            expect { subject.perform }.to raise_error(PgHero::Error)
          end
        end
      end
    end
  end
end
