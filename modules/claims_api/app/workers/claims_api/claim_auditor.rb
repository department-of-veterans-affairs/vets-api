# frozen_string_literal: true

require 'sidekiq'
require 'sentry_logging'

module ClaimsApi
  class ClaimAuditor
    include Sidekiq::Worker
    include SentryLogging

    def perform
      return unless Settings.claims_api.audit_enabled

      claims = ClaimsApi::AutoEstablishedClaim.where(created_at: 1.day.ago..Time.zone.now)
                                              .where(status: ClaimsApi::AutoEstablishedClaim::ERRORED)

      return unless claims.any?

      client = SlackNotify::Client.new(webhook_url: Settings.claims_api.slack.webhook_url,
                                       channel: '#api-benefits-claims',
                                       username: 'ClaimAuditor')
      environment_name = Settings.claims_api.claims_error_reporting.environment_name
      message = "#{claims.count} claim#{claims.count == 1 ? '' : 's'} in #{environment_name} "\
                'has an errored status.  '\
                'Please check these claims to determine if any resubmissions or other fixes are required.\n\n'

      message += "*Claim ids:*\n"
      claims.each { |claim| message += "- `#{claim.id}`\n" }
      client.notify(message)
    end
  end
end
