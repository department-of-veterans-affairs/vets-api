module CentralMail
  class DeleteOldClaims
    include Sidekiq::Worker

    EXPIRATION_TIME = 2.months

    def perform
      PensionBurial::TagSentry.tag_sentry

      CentralMailClaim.joins(:central_mail_submission).where.not(
        central_mail_submissions: { state: 'pending' }
      ).where(
        'created_at < ?', EXPIRATION_TIME.ago
      ).find_each do |central_mail_claim|
        central_mail_claim.destroy!
      end
    end
  end
end
