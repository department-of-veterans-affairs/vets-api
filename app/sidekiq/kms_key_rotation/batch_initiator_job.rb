# frozen_string_literal: true

module KmsKeyRotation
  class BatchInitiatorJob
    include Sidekiq::Worker

    sidekiq_options retry: false, queue: :low

    RECORDS_PER_BATCH = 1_000_000
    RECORDS_PER_JOB = 100

    def perform
      return nil if records.empty?

      batched_gids.each do |gids|
        KmsKeyRotation::RotateKeysJob.perform_async(gids)
      end
    end

    def records
      @records ||= begin
        version = KmsEncryptedModelPatch.kms_version

        models.each_with_object([]) do |model, records|
          needed = RECORDS_PER_BATCH - records.size

          break records if needed.zero?

          records.concat(
            model.where.not('encrypted_kms_key LIKE ?', "v#{version}:%").limit(needed)
          )
        end
      end
    end

    private

    def models
      @models ||= ApplicationRecord.descendants_using_encryption.map(&:name).map(&:constantize)
    end

    def batched_gids
      records.map(&:to_global_id).each_slice(RECORDS_PER_JOB).to_a
    end
  end
end
