# frozen_string_literal: true

module KmsKeyRotation
  class BatchInitiatorJob
    include Sidekiq::Worker

    sidekiq_options retry: false, queue: :low

    MAX_RECORDS_PER_BATCH = 100_000
    MAX_RECORDS_PER_JOB = 100

    MODELS_FOR_QUERY = {
      'ClaimsApi::V2::AutoEstablishedClaim' => ClaimsApi::AutoEstablishedClaim
    }.freeze

    def perform
      records_enqueued = 0

      models.each do |model|
        if records_enqueued >= MAX_RECORDS_PER_BATCH
          Rails.logger.info("Maximum enqueued #{records_enqueued} records for key rotation reached. Stopping.")
          break
        end

        Rails.logger.info("Enqueuing #{model} records for key rotation. #{records_enqueued} records enqueued so far")

        gids_for_model(model).each_slice(MAX_RECORDS_PER_JOB) do |slice|
          KmsKeyRotation::RotateKeysJob.perform_async(slice)
        end

        records_enqueued += gids.size
      end
    rescue => e
      Rails.logger.error("An error occurred during processing: #{e.message}")
    end

    private

    def models
      @models ||= ApplicationRecord.descendants_using_encryption.map(&:name).map(&:constantize)
    end

    def gids_for_model(model)
      model = MODELS_FOR_QUERY[model.name] if MODELS_FOR_QUERY.key?(model.name)

      model
        .where.not('encrypted_kms_key LIKE ?', "v#{KmsEncryptedModelPatch.kms_version}:%")
        .limit(MAX_RECORDS_PER_BATCH)
        .pluck(model.primary_key)
        .map { |id| URI::GID.build(app: GlobalID.app, model_name: model.name, model_id: id).to_s }
    end
  end
end
