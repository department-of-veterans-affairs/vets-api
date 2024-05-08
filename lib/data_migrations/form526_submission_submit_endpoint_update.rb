# frozen_string_literal: true

module DataMigrations
  module Form526SubmissionSubmitEndpointUpdate
    module_function

    def run
      total_records = Form526Submission.where(status: nil).count

      Form526Submission.where(status: nil).find_in_batches do |batch|
        batch.update_all(submit_endpoint: :evss)
        processed_records += batch.size

        next unless (processed_records % 50_000).zero?

        puts "Processed #{processed_records} out of #{total_records} records"
      end

      puts 'Submit endpoint updated successfully'
    end
  end
end
