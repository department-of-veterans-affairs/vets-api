# frozen_string_literal: true

class PgHeroCleanQueryStatsJob
  include Sidekiq::Worker
  include SentryLogging

  def perform
    PgHero.clean_query_stats
  rescue => e
    handle_errors(e)
  end

  def handle_errors(ex)
    Rails.logger.error('PgHero Query Stat Cleanup Failed')
    log_exception_to_sentry(ex)
    raise ex
  end
end
