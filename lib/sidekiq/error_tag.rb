# frozen_string_literal: true

class Sidekiq::ErrorTag
  def call(_worker, job, _queue)
    Raven.tags_context(job: job['class'])
    yield
  end
end
