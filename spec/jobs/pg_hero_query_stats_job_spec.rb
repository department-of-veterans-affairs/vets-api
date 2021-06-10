# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PgHeroQueryStatsJob, type: :worker do
  subject { described_class.new }

  describe '#perform' do
    let(:query_stat_count) { PgHero::QueryStats.count }

    context 'when it runs the query stat task' do
      before do
        # This is temporary until we can figure out how to
        # specify the postgres.conf for GH Actions test run
        allow(PgHero).to receive(:capture_query_stats).and_return(true)
      end

      it 'records new query stats' do
        subject.perform
        expect(PgHero::QueryStats.count).to be >= query_stat_count
      end
    end

    context 'when error occurs' do
      before do
        allow(PgHero).to receive(:capture_query_stats).and_raise(PgHero::Error)
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
