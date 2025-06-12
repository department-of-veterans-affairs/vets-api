# frozen_string_literal: true

module SchemaContract
  class ValidationInitiator
    def self.call(user:, response:, contract_name:)
      if response.success?
        body = response.body
        initiate_validation(user:, body:, contract_name:)
      end
    rescue => e
      # blanket rescue to avoid blocking main thread execution
      message = { response:, contract_name:, error_details: e.message }
      Rails.logger.error('Error creating schema contract job', message)
    end

    def self.call_with_body(user:, body:, contract_name:)
      initiate_validation(user:, body:, contract_name:)
    rescue => e
      # blanket rescue to avoid blocking main thread execution
      message = { body:, contract_name:, error_details: e.message }
      Rails.logger.error('Error creating schema contract job with body', message)
    end

    private

    def self.initiate_validation(user:, body:, contract_name:)
      if Flipper.enabled?("schema_contract_#{contract_name}")
        return if SchemaContract::Validation.where(contract_name:, created_at: Time.zone.today.all_day).any?

        record = SchemaContract::Validation.create(
          contract_name:, user_account_id: user.user_account_uuid, user_uuid: user.uuid,
          response: body, status: 'initialized'
        )
        Rails.logger.info('Initiating schema contract validation', { contract_name:, record_id: record.id })
        SchemaContract::ValidationJob.perform_async(record.id)
      end
    end
  end
end
