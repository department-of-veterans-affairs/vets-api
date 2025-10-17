# frozen_string_literal: true

module KmsKeyRotation
  class RotateKeysJob
    include Sidekiq::Worker

    sidekiq_options retry: false, queue: :low

    def perform(gids)
      Rails.logger.info { "Re-encrypting records: #{gids.join ', '}" }
      records = GlobalID::Locator.locate_many gids

      records.each do |r|
        original_key = r.encrypted_kms_key
        r.rotate_kms_key!
        rotated_key = r.encrypted_kms_key

        # rubocop is disabled because the updated_at field MUST stay the same
        # rubocop:disable Rails/SkipsModelValidations
        r.update_column('needs_kms_rotation', false) unless original_key == rotated_key
        # rubocop:enable Rails/SkipsModelValidations
      rescue => e
        Rails.logger.error("Error rotating record (id: #{r.to_global_id}): #{e.message}")
      end
    end
  end
end
