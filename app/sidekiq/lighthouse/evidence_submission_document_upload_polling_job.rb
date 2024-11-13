# frozen_string_literal: true

module Lighthouse
  class EvidenceSubmissionDocumentUploadPollingJob
    include Sidekiq::Job

    # TODO: Determine how many sidekiq retries we want to have
    # sidekiq_options retry: 7

    # TODO: Determine how many batched documents we want to poll at a time
    # POLLED_BATCH_DOCUMENT_COUNT = 100
  end
end