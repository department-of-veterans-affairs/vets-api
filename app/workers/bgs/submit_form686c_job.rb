# frozen_string_literal: true

require 'bgs/form686c'

module BGS
  class SubmitForm686cJob < Job
    class Invalid686cClaim < StandardError; end
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

      BGS::Form686c.new(user).submit(claim_data)
      in_progress_form&.destroy
    rescue
      salvage_save_in_progress_form(FORM_ID, user_uuid, in_progress_copy)
      DependentsApplicationFailureMailer.build(user).deliver_now if user.present?
    else
      VBMS::SubmitDependentsPdfJob.perform_async(
        saved_claim_id,
        vet_info,
        @submittable_686,
        @submittable_674
      )
    end

    private

    def valid_claim_data(saved_claim_id, vet_info)
      claim = SavedClaim::DependencyClaim.find(saved_claim_id)

      claim.add_veteran_info(vet_info)

      raise Invalid686cClaim unless claim.valid?(:run_686_form_jobs)

      @submittable_686 = claim.submittable_686?
      @submittable_674 = claim.submittable_674?
      claim.formatted_686_data(vet_info)
    end
  end
end
