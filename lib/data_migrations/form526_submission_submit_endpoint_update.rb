# frozen_string_literal: true

module DataMigrations
  module Form526SubmissionSubmitEndpointUpdate
    module_function

    def run
      submissions = Form526Submission.where(submit_endpoint: nil)
      total_submissions = submissions.count

      submissions.find_in_batches do |batch|
        # rubocop:disable Rails/SkipsModelValidations
        batch.update_all(submit_endpoint: :evss)
        # rubocop:enable Rails/SkipsModelValidations
        processed_submissions += batch.size

        next unless (processed_submissions % 50_000).zero?

        # rubocop:disable Rails/Output
        puts "Processed #{processed_submissions} out of #{total_submissions} submissions"
      end

      puts 'Submit endpoint updated successfully'
      # rubocop:enable Rails/Output
    end
  end
end
