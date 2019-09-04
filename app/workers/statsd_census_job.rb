# frozen_string_literal: true

##
# This job should be scheduled to run every 30m or so. Its purpose is to ensure all StatsD.increment metrics are
# initialized with a StatsD.increment(stat_key, 0) so they can properly be captured by Grafana#
class StatsdCensusJob
  KNOWN_STATSD_TAGS = [].freeze
  STATS_ROSTER_SET = "incremented_metrics"

  include Sidekiq::Worker
  sidekiq_options(retry: false)

  def perform
    initialize_stats_roster unless stats_roster_is_in_redis?
    audit_roster!
  end

  private

  def initialize_stats_roster
    #Redis does not store empty sets
    #sets also don't store dups, so we don't have to worry about duplicate statsD keys being stored in the SET
  end

  def stats_roster_is_in_redis?
    Redis.current.exists(STATS_ROSTER_SET)
  end
  
  def stats_key_in_redis_set? tag
    Redis.current.sismember(STATS_ROSTER_SET, tag)
  end
  
  def add_metric_to_stats_roster tag
    #todo set the expire time/TTL for each tag in the set
    # r.expire("key", seconds)
    Redis.current.sadd(STATS_ROSTER_SET, tag)
  end

  def audit_roster!
    # Import all the services so we can auto-initialize StatsD stuff
    # this takes care of the "known" keys, we'll need to modify with_monitoring to take care of dynamic keys
    Dir.glob("#{Rails.root}/lib/**/*.rb").grep(/service/).each { |f| require_dependency(f) }
    classes = Common::Client::Base.descendants.map(&:to_s).sort
    statsd_classes = classes.select { |k| k.constantize.constants.include? (:STATSD_KEY_PREFIX) }
    # add_metric_to_stats_roster( statsd_classes )
    # TODO make sure the with_monitoring part is handled
  end
end
