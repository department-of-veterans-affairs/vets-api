# frozen_string_literal: true

require 'sidekiq'

module VBADocuments
  class UploadStatusBatch
    include Sidekiq::Job

    # No need to retry since the schedule will run this every hour
    sidekiq_options retry: false, unique_for: 1.hour

    BATCH_SIZE = 100

    EMMS_SYSTEM_IO_ERROR = 'Upstream status: System.IO.IOException: The process cannot access the file%'
    EMMS_DUP_CONFIRM_NUMBER_ERROR = 'ERR-EMMS-FAILED, ConfirmationNumber has already been submitted%'

    def perform
      return unless enabled? && filtered_submission_guids.present?

      Sidekiq::Batch.new.jobs do
        filtered_submission_guids.each_slice(BATCH_SIZE).with_index do |guids, i|
          # Stagger jobs by a few seconds so that we don't overwhelm the upstream service
          VBADocuments::UploadStatusUpdater.perform_in((i * 5).seconds, guids)
        end
      end
    end

    private

    def filtered_submission_guids
      ups = VBADocuments::UploadSubmission.in_flight

      # Unlike most errors, these seem to be self resolving internal EMMS error, so continue
      # to update the status for 30 days, so far all of the summissions that hit these errors recover on their own
      # without us doing anything other than fetching their latest status
      ups = ups.or(VBADocuments::UploadSubmission
                     .where(status: 'error')
                     .where('detail LIKE ? or detail LIKE ?', EMMS_SYSTEM_IO_ERROR, EMMS_DUP_CONFIRM_NUMBER_ERROR)
                     .where(created_at: 30.days.ago..))
      ups.order(created_at: :asc).pluck(:guid)
    end

    def enabled?
      Settings.vba_documents.updater_enabled
    end
  end
end
