# frozen_string_literal: true

module Form1095
  class DeleteOld1095BsJob
    include Sidekiq::Job

    # This job deletes Form1095B forms for years prior to the current tax year.
    # Limiting the number of records deleted in a single batch to prevent database impact.
    # This limit can be overriden when running manually.
    def perform(limit = 100_000)
      forms_to_delete = Form1095B.where('tax_year < ?', Form1095B.current_tax_year).limit(limit)
      if forms_to_delete.none?
        log_message('No old Form1095B records to delete')
        return
      end

      log_message("Begin deleting #{forms_to_delete.count} old Form1095B files")
      start_time = Time.now.to_f
      forms_to_delete.in_batches(&:delete_all)
      duration = Time.now.to_f - start_time
      log_message("Finished deleting old Form1095B files in #{duration} seconds")
    end

    private

    def log_message(message)
      Rails.logger.info("Form1095B Deletion Job: #{message}")
    end
  end
end
