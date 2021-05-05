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

      context 'when error occurs' do
        before do
          allow_any_instance_of(PgHeroCleanQueryStatsJob).to receive(:handle_errors)
            .and_return('stub error handling')
          allow(PgHero).to receive(:clean_query_stats).and_raise(PgHero::Error)
        end

        it 'raises an exception when an error occurs' do
          expect(subject.perform).to eq('stub error handling')
        end
      end
    end
  end
end
