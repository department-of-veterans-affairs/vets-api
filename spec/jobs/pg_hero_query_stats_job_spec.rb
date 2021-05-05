# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PgHeroQueryStatsJob, type: :worker do
  subject { described_class.new }

  describe '#perform' do
    let(:query_stat_count) { PgHero::QueryStats.count }

    context 'when it runs the query stat task' do
      it 'deletes old records' do
        subject.perform
        expect(PgHero::QueryStats.count).to be >= query_stat_count
      end
    end

    context 'when error occurs' do
      before do
        allow_any_instance_of(PgHeroQueryStatsJob).to receive(:handle_errors)
          .and_return('stub error handling')
        allow(PgHero).to receive(:capture_query_stats).and_raise(PgHero::Error)
      end

      it 'raises an exception when an error occurs' do
        expect(subject.perform).to eq('stub error handling')
      end
    end
  end
end
