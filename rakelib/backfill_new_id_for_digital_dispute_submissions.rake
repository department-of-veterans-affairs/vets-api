# frozen_string_literal: true

desc 'Backfill new_id column for digital_dispute_submissions records using sequence'
task backfill_new_id_for_digital_dispute_submissions: :environment do
  Rails.logger.info('[BackfillNewIdForDigitalDisputeSubmissions] Starting rake task')

  initial_count = DebtsApi::V0::DigitalDisputeSubmission.where(new_id: nil).count
  Rails.logger.info("[BackfillNewIdForDigitalDisputeSubmissions] Records to backfill: #{initial_count}")

  updated_count = 0
  DebtsApi::V0::DigitalDisputeSubmission.where(new_id: nil).find_in_batches(batch_size: 1000) do |batch|
    batch.each do |submission|
      new_id_value = ActiveRecord::Base.connection.select_value(
        "SELECT nextval('digital_dispute_submissions_new_id_seq')"
      )
      submission.update_column(:new_id, new_id_value) # rubocop:disable Rails/SkipsModelValidations
      updated_count += 1
    end
  end

  Rails.logger.info("[BackfillNewIdForDigitalDisputeSubmissions] Finished - updated #{updated_count} records")

  remaining_count = DebtsApi::V0::DigitalDisputeSubmission.where(new_id: nil).count
  Rails.logger.info("[BackfillNewIdForDigitalDisputeSubmissions] Remaining null new_id: #{remaining_count}")
end
