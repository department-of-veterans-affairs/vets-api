# frozen_string_literal: true

class Sidekiq::SetRequestAttributes
  def call(_worker, job, _queue, _redis_pool)
    additional_request_attributes = Thread.current['additional_request_attributes'] || {}
    job['remote_ip'] = additional_request_attributes.fetch('remote_ip', 'N/A')
    job['user_agent'] = additional_request_attributes.fetch('user_agent', 'N/A')

    yield
  end
end
