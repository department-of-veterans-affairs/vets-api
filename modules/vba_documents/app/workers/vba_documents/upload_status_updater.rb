# frozen_string_literal: true

require 'sidekiq'

module VBADocuments
  class UploadStatusUpdater
    include Sidekiq::Worker

    sidekiq_options queue: 'vba_documents', retry: true

    def perform
      unless already_running?
        VBADocuments::UploadSubmission.in_flight.order(created_at: :asc).find_in_batches(batch_size: 100).each do |batch|
          VBADocuments::UploadSubmission.refresh_statuses!(batch)
        end
      end
    end

    def already_running?
      queue = Sidekiq::Queue.new('vba_documents')
      job_classes = queue.map{ |job| job.klass} 
      job_classes.include? 'UploadStatusUpdater' 
    end
  end
end
