# frozen_string_literal: true

desc 'Backfill new_id column for digital_dispute_submissions records using sequence'
task backfill_new_id_for_digital_dispute_submissions: :environment do
  Rails.logger.info('[BackfillNewIdForDigitalDisputeSubmissions] Starting rake task')

  initial_count = DebtsApi::V0::DigitalDisputeSubmission.where(new_id: nil).count
  Rails.logger.info("[BackfillNewIdForDigitalDisputeSubmissions] Records to backfill: #{initial_count}")

  updated_count = ActiveRecord::Base.connection.update(<<~SQL.squish)
    UPDATE digital_dispute_submissions
    SET new_id = nextval('digital_dispute_submissions_new_id_seq')
    WHERE new_id IS NULL
  SQL

  Rails.logger.info("[BackfillNewIdForDigitalDisputeSubmissions] Finished - updated #{updated_count} records")
end
