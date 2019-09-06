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
    # initialize_stats_roster unless stats_roster_is_in_redis?
    audit_roster!
  end

  private

  def stats_roster_is_in_redis?
    Redis.current.exists(STATS_ROSTER_SET)
  end
  
  def stats_key_in_redis_set? key
    Redis.current.sismember(STATS_ROSTER_SET, key)
  end
  
  def add_metric_to_stats_roster keys
    #todo set the expire time/TTL for each tag in the set
    # r.expire("key", seconds)
    keys.each { |key| Redis.current.zadd(STATS_ROSTER_SET, Time.now.to_f, key) } 
  end

  def audit_roster!
    # Import all the services so we can auto-initialize StatsD stuff
    # this takes care of the "known" keys, we'll need to modify with_monitoring to take care of dynamic keys
    Dir.glob("#{Rails.root}/lib/**/*.rb").grep(/service/).each { |f| require_dependency(f) }
    classes = Common::Client::Base.descendants.map(&:to_s).sort
    statsd_classes = classes.select { |k| k.constantize.constants.include? (:STATSD_KEY_PREFIX) }
    add_metric_to_stats_roster( statsd_classes )
    # TODO make sure the with_monitoring part is handled
    #Todo update TTL for existing keys update_ttl_for_existing_keys
  end
  
  def update_ttl_for_existing_keys
    all_keys = Redis.current.zrange(STATS_ROSTER_SET, 0, -1)
    #todo -- Refresh the `TTL` of already-existing entries -- if TTL > 1.week, update
  end
  
end
