# frozen_string_literal: true

module KmsKeyRotation
  class BatchInitiatorJob
    include Sidekiq::Worker

    sidekiq_options retry: false, queue: :low

    MAX_RECORDS_PER_BATCH = 15_000_000
    MAX_RECORDS_PER_JOB = 100

    MODELS_FOR_QUERY = {
      'ClaimsApi::V2::AutoEstablishedClaim' => ClaimsApi::AutoEstablishedClaim
    }.freeze

    def perform(max_records_per_job = MAX_RECORDS_PER_JOB, max_records_per_batch = MAX_RECORDS_PER_BATCH)
      flag_rotation_records_on_rotation_day

      records_enqueued = 0

      models.each do |model|
        if records_enqueued >= max_records_per_batch
          Rails.logger.info("Maximum enqueued #{records_enqueued} records for key rotation reached. Stopping.")
          break
        end

        Rails.logger.info("Enqueuing #{model} records for key rotation. #{records_enqueued} records enqueued so far")

        gids = gids_for_model(model, max_records_per_batch)

        gids.each_slice(max_records_per_job) do |slice|
          KmsKeyRotation::RotateKeysJob.perform_async(slice)
        end

        records_enqueued += gids.size
      end
    end

    private

    def models
      @models ||= ApplicationRecord.descendants_using_encryption.map(&:name).map(&:constantize)
    end

    def gids_for_model(model, max_records_per_batch)
      model = MODELS_FOR_QUERY[model.name] if MODELS_FOR_QUERY.key?(model.name)

      model
        .where(needs_kms_rotation: true)
        .limit(max_records_per_batch)
        .pluck(model.primary_key)
        .map { |id| URI::GID.build(app: GlobalID.app, model_name: model.name, model_id: id).to_s }
    end

    def rotation_date?
      today = Time.zone.today
      today.month == 10 && today.day == 12
    end

    def flag_rotation_records_on_rotation_day
      return unless rotation_date?

      Rails.logger.info '[KmsKeyRotation] Flagging every record for rotation on October 12th'

      models.each do |encrypted_model|
        model = MODELS_FOR_QUERY.fetch(encrypted_model.name, encrypted_model)
        model.update_all(needs_kms_rotation: true) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end
end
