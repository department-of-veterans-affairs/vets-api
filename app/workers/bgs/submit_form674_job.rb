# frozen_string_literal: true

require 'bgs/form674'

module BGS
  class SubmitForm674Job
    class Invalid674Claim < StandardError; end
    include Sidekiq::Worker
    include SentryLogging

    # we do individual service retries in lib/bgs/service.rb
    sidekiq_options retry: false

    def perform(user_uuid, saved_claim_id, vet_info)
      user = User.find(user_uuid)
      claim_data = valid_claim_data(saved_claim_id, vet_info)

      BGS::Form674.new(user).submit(claim_data)
    rescue
      DependentsApplicationFailureMailer.build(user).deliver_later if user.present?
    end

    private

    def valid_claim_data(saved_claim_id, vet_info)
      claim = SavedClaim::DependencyClaim.find(saved_claim_id)

      raise Invalid674Claim unless claim.valid?(:run_686_form_jobs)

      claim.formatted_674_data(vet_info)
    end
  end
end
