# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SidekiqStatsJob, type: :job do
  subject do
    described_class.new
  end

  # allow_any_instance_of(Sidekiq::Stats).to receive().and_return()
  describe '#perform' do
    before(:each) do
      # this method calls gauge multiple times, allow the ones we aren't testing
      allow(StatsD).to receive(:gauge)
    end
    context 'METRIC_NAMES' do
      it 'should send statsd a gauge of the info to shared.sidekiq.stats.METRIC_NAME'
    end
    fit 'should gauge number of working jobs' do
      busy_process_set = [1,2,3]
      allow_any_instance_of(Sidekiq::ProcessSet).to receive(:select).and_return(busy_process_set)
      expect(StatsD).to receive(:gauge).with('shared.sidekiq.stats.working', busy_process_set.count)
      subject.perform
    end
    it 'should gauge the size of each queue'
  end
end
