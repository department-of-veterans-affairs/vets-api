# frozen_string_literal: true

require 'sidekiq'
require 'sentry_logging'

module ClaimsApi
  class ClaimAuditor
    include Sidekiq::Worker
    include SentryLogging

    def perform
      return unless Settings.claims_api.audit_enabled

      report_threshold = Settings.claims_api.claims_pending_reporting.threshold
      claims = ClaimsApi::AutoEstablishedClaim.where(status: ClaimsApi::AutoEstablishedClaim::PENDING)
                                              .where('created_at < ?', (report_threshold / 1000).seconds.ago)
      return unless claims.any?

      client = SlackNotify::Client.new(webhook_url: Settings.claims_api.slack.webhook_url,
                                       channel: '#api-benefits-claims',
                                       username: 'ClaimAuditor')
      environment_name = Settings.claims_api.claims_pending_reporting.environment_name
      message = "#{claims.count} claims in #{environment_name} surpass defined pending status threshold: "
      message += "#{report_threshold}ms"
      client.notify(message)
    end
  end
end
