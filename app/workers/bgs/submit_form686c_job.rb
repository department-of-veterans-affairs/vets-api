# frozen_string_literal: true

module BGS
  class SubmitForm686cJob
    include Sidekiq::Worker

    # we do individual service retries in lib/bgs/service.rb
    sidekiq_options retry: false

    def perform(_user_uuid, saved_claim_id, va_file_number_with_payload)
      user = User.find(user_uuid)
      claim = SavedClaim::DependencyClaim.find(saved_claim_id)

      claim.add_veteran_info(va_file_number_with_payload)

      # This PR is blocked until others are ready
      BGS::Form686c.new(user).submit(claim.parsed_form)
    end
  end
end
