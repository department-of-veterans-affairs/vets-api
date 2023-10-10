# frozen_string_literal: true

module KmsKeyRotation
  class BatchComplete
    def on_complete(_status, _options)
      BatchInitiatorJob.perform_async
    end
  end

  class BatchInitiatorJob
    include Sidekiq::Worker

    sidekiq_options retry: 5, queue: :low

    RECORDS_PER_BATCH = 10_000
    RECORDS_PER_JOB = 1_000

    def perform
      batch = Sidekiq::Batch.new
      batch.description = "KMS Key Rotation #{batch.bid}"
      batch.on(:complete, BatchComplete)

      return nil if records.empty?

      batch.jobs do
        Sidekiq::Client.push_bulk('class' => KmsKeyRotation::RotateKeysJob, 'args' => batched_gids)
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
      records.map(&:to_global_id).each_slice(RECORDS_PER_JOB).map { |gids| [{ gids: }] }
    end
  end
end
