# frozen_string_literal: true

require 'sidekiq'

module VBADocuments
  class RunUnsuccessfulSubmissions
    include Sidekiq::Worker

    def perform
      guids = VBADocuments::UploadSubmission.where(status: 'uploaded').pluck(:guid)
      guids.each do |guid|
        Rails.logger.info("Running VBADocuments::RunUnsuccessfulSubmissions for GUID #{guid}",
                          { 'job' => 'VBADocuments::RunUnsuccessfulSubmissions', guid: guid })
        VBADocuments::UploadProcessor.perform_async(guid)
      end
    end
  end
end
