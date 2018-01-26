module VIC
  class VICSubmission
    include SetGuid

    attr_accessor(:form)

    after_create(:create_submission_job)

    # TODO validate form

    private

    def create_submission_job
      SubmissionJob.perform_async(id, form)
    end
  end
end
