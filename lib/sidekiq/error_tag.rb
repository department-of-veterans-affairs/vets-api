# frozen_string_literal: true

class Sidekiq::ErrorTag
  def call(_worker, job, _queue)
    Raven.tags_context(job: job['class'])

    if job['request_attributes'].is_a?(Hash)
      Raven.tags_context(request_id: job['request_id'])
      Raven.user_context(remote_ip:  job.dig('request_attributes', 'remote_ip'))
      Raven.user_context(user_agent: job.dig('request_attributes', 'user_agent'))
    end

    yield
  end
end
