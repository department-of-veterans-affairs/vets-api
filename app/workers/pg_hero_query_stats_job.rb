# frozen_string_literal: true

class PgHeroQueryStatsJob
  include Sidekiq::Worker
  include SentryLogging

  def perform
    PgHero.capture_query_stats
  rescue => e
    handle_errors(e)
  end

  def handle_errors(ex)
    Rails.logger.error('PgHero Query Stat Capture Failed')
    log_exception_to_sentry(ex)
    raise ex
  end
end
