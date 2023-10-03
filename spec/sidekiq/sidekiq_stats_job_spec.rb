# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/api'

RSpec.describe SidekiqStatsJob, type: :job do
  subject do
    described_class.new
  end

  describe '#perform' do
    before do
      # this method calls gauge multiple times, allow the ones we aren't testing
      allow(StatsD).to receive(:gauge)
    end

    context 'for METRIC_NAMES' do
      SidekiqStatsJob::METRIC_NAMES.each do |metric|
        metric_key = "shared.sidekiq.stats.#{metric}"
        it "sends statsd a gauge of the info to #{metric_key}" do
          stat = [1, 3, 7, 11].sample
          expect_any_instance_of(Sidekiq::Stats).to receive(metric).and_return(stat)
          expect(StatsD).to receive(:gauge).with(metric_key, stat)
          subject.perform
        end
      end
    end

    it 'gauges number of working jobs' do
      busy_process_set = [1, 2, 3]
      allow_any_instance_of(Sidekiq::ProcessSet).to receive(:select).and_return(busy_process_set)
      expect(StatsD).to receive(:gauge).with('shared.sidekiq.stats.working', busy_process_set.count)
      subject.perform
    end

    it 'gauges the size of each queue' do
      queues = { 'queue1' => 4, 'queue2' => 44 }
      allow_any_instance_of(Sidekiq::Stats).to receive(:queues).and_return(queues)
      queues.each do |name, size|
        expect(StatsD).to receive(:gauge).with("shared.sidekiq.#{name}.size", size)
      end
      subject.perform
    end
  end
end
