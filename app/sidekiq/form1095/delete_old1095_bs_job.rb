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
        Rails.logger.info('No old Form1095B records to delete')
        return
      end

      Rails.logger.info("Begin deleting #{forms_to_delete.count} old Form1095B files")
      start_time = Time.now.to_f
      forms_to_delete.in_batches(&:delete_all)
      duration = Time.now.to_f - start_time
      Rails.logger.info("Finished deleting old Form1095B files in #{duration} seconds")
    end
  end
end
