# frozen_string_literal: true

module KmsKeyRotation
  class RotateKeysJob
    include Sidekiq::Worker

    sidekiq_options retry: false, queue: :low

    def perform(gids)
      Rails.logger.info { "Re-encrypting records: #{gids.join ', '}" }
      records = GlobalID::Locator.locate_many gids

      skip_hq_callback do
        records.each do |r|
          r.rotate_kms_key!
        rescue => e
          Rails.logger.error("Error rotating record (id: #{r.to_global_id}): #{e.message}")
        end
      end
    end

    private

    def skip_hq_callback
      HealthQuest::QuestionnaireResponse.skip_callback :save, :before, :set_user_demographics, raise: false
      yield
      HealthQuest::QuestionnaireResponse.set_callback :save, :before, :set_user_demographics, raise: false
    end
  end
end
