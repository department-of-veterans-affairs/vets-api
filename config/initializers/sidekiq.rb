# frozen_string_literal: true

require 'sidekiq_stats_instrumentation/client_middleware'
require 'sidekiq_stats_instrumentation/server_middleware'
require 'sidekiq/retry_monitoring'
require 'sidekiq/error_tag'
require 'sidekiq/semantic_logging'
require 'sidekiq/set_request_id'
require 'sidekiq/set_request_attributes'
require 'datadog/statsd' # gem 'dogstatsd-ruby'

Rails.application.reloader.to_prepare do
  Sidekiq::Enterprise.unique! if Rails.env.production?

  Sidekiq.configure_server do |config|
    config.redis = REDIS_CONFIG[:sidekiq]
    # super_fetch! is only available in sidekiq-pro and will cause
    #   "undefined method `super_fetch!'"
    # for those using regular sidekiq
    config.super_fetch! if defined?(Sidekiq::Pro)

    config.on(:startup) do
      Sidekiq.schedule = YAML.safe_load(
        ERB.new(File.read(File.expand_path('../sidekiq_scheduler.yml', __dir__))).result
      )
      Sidekiq::Scheduler.reload_schedule!
    end

    config.server_middleware do |chain|
      chain.add Sidekiq::SemanticLogging
      chain.add SidekiqStatsInstrumentation::ServerMiddleware
      chain.add Sidekiq::RetryMonitoring
      chain.add Sidekiq::ErrorTag

      if Settings.dogstatsd.enabled == true
        require 'sidekiq/middleware/server/statsd'
        chain.add Sidekiq::Middleware::Server::Statsd
        config.dogstatsd = -> { Datadog::Statsd.new('localhost', 8125, namespace: 'sidekiq') }

        # history is captured every 30 seconds by default
        config.retain_history(30)
      end
    end

    config.client_middleware do |chain|
      chain.add SidekiqStatsInstrumentation::ClientMiddleware
    end

    if defined?(Sidekiq::Enterprise)
      config.periodic do |mgr|
        mgr.register('0 5 * * 1', 'AppealsApi::WeeklyErrorReport')

        mgr.register('5 * * * *', 'AppealsApi::HigherLevelReviewUploadStatusBatch')
        # Update HigherLevelReview statuses with their Central Mail status
        mgr.register('10 * * * *', 'AppealsApi::NoticeOfDisagreementUploadStatusBatch')
        # Update NoticeOfDisagreement statuses with their Central Mail status
        mgr.register('15 * * * *', 'AppealsApi::SupplementalClaimUploadStatusBatch')
        # Update SupplementalClaim statuses with their Central Mail status
        mgr.register('0 2,9,16 * * MON-FRI', 'AppealsApi::FlipperStatusAlert')
        # Checks status of Flipper features expected to be enabled and alerts to Slack if any are not enabled"

        mgr.register('35 * * * *', 'AppsApi::FetchConnections')
        # "Fetches and handles notifications for recent application connections and disconnections

        mgr.register('0 2,9,16 * * MON-FRI', 'VBADocuments::FlipperStatusAlert')
        mgr.register('0 2,9,16 * * MON-FRI', 'VBADocuments::SlackNotifier')
        # Notifies slack channel if certain benefits states get stuck
        mgr.register('5 */2 * * *', 'VBADocuments::RunUnsuccessfulSubmissions')
        # Run VBADocuments::UploadProcessor for submissions that are stuck in uploaded status
        mgr.register('0 0 * * MON-FRI', 'VBADocuments::ReportUnsuccessfulSubmissions')
        # Daily report of unsuccessful benefits intake submissions
        mgr.register('*/2 * * * *', 'VBADocuments::UploadRemover')
        # Clean up submitted documents from S3
        mgr.register('*/2 * * * *', 'VBADocuments::UploadScanner')
        # Poll upload bucket for unprocessed uploads
        mgr.register('45 * * * *', 'VBADocuments::UploadStatusBatch')
        # Request updated statuses for benefits intake submissions

        mgr.register('0 2,9,16 * * MON-FRI', 'VAForms::FlipperStatusAlert')
        mgr.register('0 2 * * *', 'VAForms::FetchLatest')

        mgr.register('0 16 * * *', 'VANotify::InProgressForms')
        mgr.register('0 1 * * *', 'VANotify::ClearStaleInProgressRemindersSent')
        mgr.register('0 * * * *', 'VANotify::InProgress1880Form')

        mgr.register('0 * * * *', 'PagerDuty::CacheGlobalDowntime')
        mgr.register('*/3 * * * *', 'PagerDuty::PollMaintenanceWindows')

        mgr.register('0 2 * * *', 'InProgressFormCleaner')
        mgr.register('0 */4 * * *', 'MHV::AccountStatisticsJob')
        mgr.register('0 3 * * *', 'Form1095::New1095BsJob')
        mgr.register('0 2 * * *', 'Veteran::VSOReloader')
        mgr.register('30 2 * * *', 'Identity::UserAcceptableVerifiedCredentialTotalsJob')
        mgr.register('* 7 * * *', 'SignIn::DeleteExpiredSessionsJob')
        mgr.register('15 2 * * *', 'Preneeds::DeleteOldUploads')

        mgr.register('* * * * *', 'SidekiqStatsJob')
        mgr.register('* * * * *', 'ExternalServicesStatusJob')
        mgr.register('* * * * *', 'ExportBreakerStatus')

        mgr.register('0 0 * * *', 'FeatureCleanerJob')
        mgr.register('0 0 * * *', 'Form1010cg::DeleteOldUploadsJob')
        mgr.register('0 1 * * *', 'TransactionalEmailAnalyticsJob')
      end
    end
  end

  Sidekiq.configure_client do |config|
    config.redis = REDIS_CONFIG[:sidekiq]

    config.client_middleware do |chain|
      chain.add SidekiqStatsInstrumentation::ClientMiddleware
      chain.add Sidekiq::SetRequestId
      chain.add Sidekiq::SetRequestAttributes
    end

    # Remove the default error handler
    config.error_handlers.delete_if { |handler| handler.is_a?(Sidekiq::ExceptionHandler::Logger) }
  end
end
