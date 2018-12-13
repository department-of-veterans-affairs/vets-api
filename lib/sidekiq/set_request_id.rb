# frozen_string_literal: true

class Sidekiq::SetRequestId
  def call(_worker, job, _queue, _redis_pool)
    job['request_id'] = Thread.current['request_id']

    yield
  end
end
