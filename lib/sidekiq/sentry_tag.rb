class Sidekiq::ErrorTag
  def call(_worker, job, _queue)
    Raven.tags_context(job: job['class'].underscore)
    yield
  end
end
