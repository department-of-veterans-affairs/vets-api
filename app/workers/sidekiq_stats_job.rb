# frozen_string_literal: true

class SidekiqStatsJob
  include Sidekiq::Worker

  sidekiq_options queue: 'critical'

  METRIC_NAMES = %w[
    processed
    failed
    scheduled_size
  ].freeze

  def perform
    info = Sidekiq::Stats.new

    self.class::METRIC_NAMES.each do |method, stat|
      stat ||= method

      StatsD.gauge "shared.sidekiq.stats.#{stat}", info.send(method)
    end

    working = Sidekiq::ProcessSet.new.select { |p| p[:busy] == 1 }.count
    StatsD.gauge 'shared.sidekiq.stats.working', working

    retry_size = Sidekiq::RetrySet.new.size
    StatsD.gauge 'shared.sidekiq.stats.retry_size', retry_size

    info.queues.each do |name, size|
      StatsD.gauge "shared.sidekiq.#{name}.size", size
    end
  end
end
