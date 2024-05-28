# frozen_string_literal: true

module DataMigrations
  module Form526SubmissionSubmitEndpointUpdate
    module_function

    def run
      Form526Submission.where(submit_endpoint: nil).in_batches do |batch|
        batch.update_all(submit_endpoint: :evss) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end
end
