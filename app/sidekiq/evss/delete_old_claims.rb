# frozen_string_literal: true

module EVSS
  class DeleteOldClaims
    include Sidekiq::Job

    sidekiq_options queue: 'low'

    def perform
      Sentry.set_tags(source: 'claims-status')
      claims = EVSSClaim.where('updated_at < ?', 1.day.ago)
      logger.info("Deleting #{claims.count} old EVSS claims")
      claims.delete_all
    end
  end
end
