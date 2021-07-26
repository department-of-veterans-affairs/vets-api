# frozen_string_literal: true

require 'bgs/form674'

module BGS
  class SubmitForm674Job < Job
    class Invalid674Claim < StandardError; end
    FORM_ID = '686C-674'
    include Sidekiq::Worker
    include SentryLogging

    # we do individual service retries in lib/bgs/service.rb
    sidekiq_options retry: false

    def perform(user_uuid, saved_claim_id, vet_info)
      in_progress_form = InProgressForm.find_by(form_id: FORM_ID, user_uuid: user_uuid)
      in_progress_copy = in_progress_form_copy(in_progress_form)
      user = User.find(user_uuid)
      claim_data = valid_claim_data(saved_claim_id, vet_info)

      BGS::Form674.new(user).submit(claim_data)
      in_progress_form&.destroy
    rescue
      salvage_save_in_progress_form(FORM_ID, user_uuid, in_progress_copy)
      DependentsApplicationFailureMailer.build(user).deliver_later if user.present?
    end

    private

    def valid_claim_data(saved_claim_id, vet_info)
      claim = SavedClaim::DependencyClaim.find(saved_claim_id)

      claim.add_veteran_info(vet_info)

      raise Invalid674Claim unless claim.valid?(:run_686_form_jobs)

      claim.formatted_674_data(vet_info)
    end
  end
end
