# frozen_string_literal: true

module KmsKeyRotation
  class RotateKeysJob
    include Sidekiq::Worker

    sidekiq_options retry: false, queue: :low

    def perform(gids)
      Rails.logger.info { "Re-encrypting records: #{gids.join ', '}" }
      records = GlobalID::Locator.locate_many gids

      records.each do |r|
        r.rotate_kms_key!
      rescue => e
        Rails.logger.error("Error rotating record (id: #{r.to_global_id}): #{e.message}")
      end
    end
  end
end
