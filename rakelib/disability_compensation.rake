# frozen_string_literal: true

namespace :disability_compensation do
  desc <<~DESC
    Download disability compensation form documents

    Use this during manual testing against the staging environment to verify
    that 526 submissions from the frontend produce the expected documents
    upstream.

    While submitting the 526 on the frontend, inspect the network tab for status
    polling to find the claim ID that should be passed to this utility. Also
    provide the user's ICN.


    ```jsonc
    {
      "data": {
        "id": "",
        "type": "form526_job_statuses",
        "attributes": {
          "claimId": "<claim_id>",
          // ...
        }
      }
    }
    ```

    EXAMPLES
      bundle exec rails disability_compensation:download_claim_documents[600878948,1012667122V019349]
  DESC

  task :download_claim_documents, %i[claim_id icn] => :environment do |_, args|
    require_relative 'disability_compensation/download_claim_documents'

    mod = DisabilityCompensation::DownloadClaimDocuments
    mod.perform(mod::FileIO, **args)
  end

  namespace :report_submission_statuses do
    require_relative 'disability_compensation/report_submission_statuses'

    mod = DisabilityCompensation::ReportSubmissionStatuses
    mod.filters.each do |filter|
      desc <<~DESC
        Generate a disability compensation submission status report for
        `#{filter}`. Can additionally target specific submission IDs.

        EXAMPLES
          bundle exec rails disability_compensation:report_submission_statuses:#{filter}
          bundle exec rails disability_compensation:report_submission_statuses:#{filter}[123,456]
      DESC

      task filter.to_sym => :environment do |_, args|
        mod.perform_async(
          "#{mod}::S3Consumer",
          "#{mod}::#{filter.classify}",
          Time.current.to_i,
          args.extras.presence
        )
      end
    end
  end
end
