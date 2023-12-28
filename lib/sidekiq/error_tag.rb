# frozen_string_literal: true

class Sidekiq::ErrorTag
  def call(_worker, job, _queue)
    Sentry.set_tags(job: job['class'], request_id: job['request_id'] || 'N/A', source: job['source'])
    Sentry.set_user(remote_ip: (job['remote_ip'] || 'N/A'),
                       user_agent: (job['user_agent'] || 'N/A'),
                       id: (job['user_uuid'] || 'N/A'))

    yield
  end
end
