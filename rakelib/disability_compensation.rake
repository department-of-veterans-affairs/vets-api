# frozen_string_literal: true

namespace :disability_compensation do
  desc <<~DESC
    Download disability compensation form documents

    Use this during manual testing against the staging environment to verify
    that 526 submissions from the frontend produce the expected documents upstream.

    While submitting the 526 on the frontend, inspect the network tab for status
    polling to find the IDs that should be passed to this utility.


    ```jsonc
    {
      "data": {
        "id": "",
        "type": "form526_job_statuses",
        "attributes": {
          "claimId": "<claim_id>",
          "jobId": "<job_id>",
          "submissionId": "<submission_id>",
          // ...
        }
      }
    }
    ```

    EXAMPLES
      bin/rails disability_compensation:download_documents[claim_id,123]
      bin/rails disability_compensation:download_documents[job_id,456]
      bin/rails disability_compensation:download_documents[submission_id,789]
  DESC

  task :download_documents, %i[id_type id_value] => :environment do |_, args|
    require_relative 'disability_compensation/download_pdfs'

    DisabilityCompensation::DownloadDocuments.perform(**args)
  end
end
