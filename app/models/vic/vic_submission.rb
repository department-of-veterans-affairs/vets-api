module VIC
  class VICSubmission < ActiveRecord::Base
    include SetGuid

    validates(:state, presence: true, inclusion: %w(success failed pending))
    validates(:response, presence: true, if: :success?)

    attr_accessor(:form)

    after_create(:create_submission_job)

    before_validation(:update_state_to_completed)

    # TODO validate form

    def success?
      state == 'success'
    end

    private

    def update_state_to_completed
      response_changes = changes['response']

      if response_changes[0].blank? && response_changes[1].present?
        self.state = 'success'
      end

      true
    end

    def create_submission_job
      SubmissionJob.perform_async(id, form)
    end
  end
end
