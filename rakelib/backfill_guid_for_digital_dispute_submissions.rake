# frozen_string_literal: true

desc 'Backfill guid column for digital_dispute_submissions records'
task backfill_guid_for_digital_dispute_submissions: :environment do
  def null_guid_count_message
    '[BackfillGuidForDigitalDisputeSubmissions] digital_dispute_submissions with guid: nil, ' \
      "count: #{guid_nil.count}"
  end

  def guid_nil
    DebtsApi::V0::DigitalDisputeSubmission.where(guid: nil)
  end

  Rails.logger.info('[BackfillGuidForDigitalDisputeSubmissions] Starting rake task')
  Rails.logger.info(null_guid_count_message)

  guid_nil.find_in_batches(batch_size: 1000) do |batch|
    batch.each do |submission|
      submission.update_column(:guid, SecureRandom.uuid) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  Rails.logger.info('[BackfillGuidForDigitalDisputeSubmissions] Finished rake task')
  Rails.logger.info(null_guid_count_message)
end
