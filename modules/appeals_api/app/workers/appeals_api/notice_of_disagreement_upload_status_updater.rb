# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class NoticeOfDisagreementUploadStatusUpdater
    include Sidekiq::Worker

    sidekiq_options 'retry': true, unique_until: :success

    def perform(ids)
      batch_size = CentralMailUpdater::MAX_UUIDS_PER_REQUEST
      NoticeOfDisagreement.where(id: ids).find_in_batches(batch_size: batch_size) do |batch|
        CentralMailUpdater.new.call(batch)
      end
    end
  end
end
