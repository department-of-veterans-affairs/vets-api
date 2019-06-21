# frozen_string_literal: true

class Sidekiq::ErrorTag
  def call(_worker, job, _queue)
    Raven.tags_context(job: job['class'])
    Raven.tags_context(request_id: job['request_id'] || 'N/A')
    Raven.user_context(remote_ip:  job['remote_ip'] || 'N/A')
    Raven.user_context(user_agent: job['user_agent'] || 'N/A')

    yield
  end
end
