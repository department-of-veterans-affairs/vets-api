# frozen_string_literal: true

class Sidekiq::SetRequestId
  def call(_worker, job, _queue, _redis_pool)
    job['request_id'] = RequestStore.store['request_id'] || 'N/A'

    yield
  end
end
