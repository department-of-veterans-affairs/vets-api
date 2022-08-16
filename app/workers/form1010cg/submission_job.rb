# frozen_string_literal: true

module Form1010cg
  class SubmissionJob
    include Sidekiq::Worker
    include SentryLogging

    sidekiq_options(retry: 14)

    def perform(claim_id)
      claim = SavedClaim::CaregiversAssistanceClaim.find(claim_id)
      Form1010cg::Service.new(claim).process_claim_v2!

      begin
        claim.destroy!
      rescue => e
        log_exception_to_sentry(e)
      end
    end
  end
end
