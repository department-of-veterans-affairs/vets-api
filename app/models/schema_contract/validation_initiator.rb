# frozen_string_literal: true

module SchemaContract
  class ValidationInitiator
    def self.call(user:, response:, contract_name:)
      if response.success? && Flipper.enabled?("schema_contract_#{contract_name}")
        return if SchemaContract::Validation.where(contract_name:, created_at: Time.zone.today.all_day).any?

        record = SchemaContract::Validation.create(
          contract_name:, user_account_id: user.user_account_uuid, user_uuid: user.uuid,
          response: response.body, status: 'initialized'
        )
        Rails.logger.info('Initiating schema contract validation', { contract_name:, record_id: record.id })
        SchemaContract::ValidationJob.perform_async(record.id)
      end
    rescue => e
      # blanket rescue to avoid blocking main thread execution
      message = { response:, contract_name:, error_details: e.message }
      Rails.logger.error('Error creating schema contract job', message)
    end
  end
end
