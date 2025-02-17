# frozen_string_literal: true

module Lighthouse
  module BenefitsIntake
    class DeleteOldClaims
      include Sidekiq::Job

      sidekiq_options retry: false

      EXPIRATION_TIME = 2.months

      def perform
        CentralMailClaim.joins(:central_mail_submission).where.not(
          central_mail_submissions: { state: 'pending' }
        ).where(
          'created_at < ?', EXPIRATION_TIME.ago
        ).find_each(&:destroy!)
      end
    end
  end
end
