# frozen_string_literal: true

##
# This job should be scheduled to run every 30m or so. Its purpose is to ensure all StatsD.increment metrics are
# initialized with a StatsD.increment(stat_key, 0) so they can properly be captured by Grafana#
class StatsDCensusJob
  KNOWN_STATSD_TAGS = [].freeze

  include Sidekiq::Worker
  sidekiq_options(retry: false)

  def perform
    initialize_stats_roster unless stats_roster_is_in_redis?
    audit_roster!
  end

  private

  def initialize_stats_roster
    Redis.current.set(stats_roster_key, 1)
  end

  def stats_roster_is_in_redis?
  end

  def audit_roster!
    # Import all the services so we can auto-initialize StatsD stuff
    # this takes care of the "known" keys, we'll need to modify with_monitoring to take care of dynamic keys
    Dir.glob("#{Rails.root}/lib/**/*.rb").grep(/service/).each { |f| require_dependency(f) }
    classes = Common::Client::Base.descendants.map(&:to_s).sort
    statsd_classes = classes.select { |k| k.constantize.constants.include? (:STATSD_KEY_PREFIX) }
    # TODO make sure the with_monitoring part is handled
  end
end
