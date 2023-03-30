# frozen_string_literal: true

require 'sidekiq'

module VBADocuments
  class RunUnsuccessfulSubmissions
    include Sidekiq::Worker

    # Only retry for ~1 hour since the job is run every two hours
    sidekiq_options retry: 7, unique_for: 2.hours

    def perform
      guids = VBADocuments::UploadSubmission.where(status: 'uploaded').pluck(:guid)
      guids.each do |guid|
        Rails.logger.info("Running VBADocuments::RunUnsuccessfulSubmissions for GUID #{guid}",
                          { 'job' => 'VBADocuments::RunUnsuccessfulSubmissions', guid: })
        VBADocuments::UploadProcessor.perform_async(guid, caller: self.class.name)
      end
    end
  end
end
