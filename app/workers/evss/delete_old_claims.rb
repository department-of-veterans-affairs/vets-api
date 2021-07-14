# frozen_string_literal: true

module EVSS
  class DeleteOldClaims
    include Sidekiq::Worker

    sidekiq_options queue: 'low'

    def perform
      Raven.tags_context(source: 'claims-status')
      claims = EVSSClaim.where('updated_at < ?', 1.day.ago)
      logger.info("Deleting #{claims.count} old EVSS claims")
      claims.delete_all
    end
  end
end
