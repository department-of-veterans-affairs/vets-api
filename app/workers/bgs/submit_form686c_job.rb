# frozen_string_literal: true

module BGS
  class SubmitForm686cJob
    class Invalid686cClaim < StandardError; end
    include Sidekiq::Worker
    include SentryLogging

    # we do individual service retries in lib/bgs/service.rb
    sidekiq_options retry: false

    def perform(user_uuid, saved_claim_id, va_file_number_with_payload)
      user = User.find(user_uuid)
      claim = SavedClaim::DependencyClaim.find(saved_claim_id)

      raise Invalid686cClaim unless claim.valid?(:run_686_form_jobs)

      claim.add_veteran_info(va_file_number_with_payload)

      BGS::Form686c.new(user).submit(claim.parsed_form)
    end
  end
end
