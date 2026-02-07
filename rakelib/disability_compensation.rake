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

    DisabilityCompensation::DownloadClaimDocuments.perform(**args)
  end
end
