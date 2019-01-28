# frozen_string_literal: true

class Sidekiq::ErrorTag
  def call(_worker, job, _queue)
    Raven.tags_context(job: job['class'])
    Raven.tags_context(request_id: job['request_id']) if job['request_id'].present?

    yield
  end
end
