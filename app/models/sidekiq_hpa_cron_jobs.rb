# frozen_string_literal: true

class SidekiqHpaCronJobs < Common::RedisStore
  def self.clean_up_queues
    SidekiqAlive::CleanupQueues.perform_async
  end
end
