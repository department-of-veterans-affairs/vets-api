# frozen_string_literal: true

require 'sidekiq'

module VBADocuments
  class RunUnsuccessfulSubmissions
    include Sidekiq::Worker

    def perform
      guids = VBADocuments::UploadSubmission.where(status: 'uploaded').pluck(:guid)
      guids.each { |guid| VBADocuments::UploadProcessor.perform_async(guid) }
    end
  end
end
