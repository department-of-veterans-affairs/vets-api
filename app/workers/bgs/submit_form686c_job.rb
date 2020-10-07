# frozen_string_literal: true

require 'bgs/form686c'

module BGS
  class SubmitForm686cJob
    class Invalid686cClaim < StandardError; end
    include Sidekiq::Worker
    include SentryLogging

    # we do individual service retries in lib/bgs/service.rb
    sidekiq_options retry: false

    def perform(user_uuid, saved_claim_id, vet_info)
      user = User.find(user_uuid)
      claim = valid_claim(saved_claim_id, vet_info)

      BGS::Form686c.new(user).submit(claim.parsed_form)
    rescue
      DependentsApplicationFailureMailer.build(user).deliver_now if user.present?
    end

    private

    def valid_claim(saved_claim_id, vet_info)
      claim = SavedClaim::DependencyClaim.find(saved_claim_id)

      claim.add_veteran_info(vet_info)

      raise Invalid686cClaim unless claim.valid?(:run_686_form_jobs)

      claim
    end
  end
end
