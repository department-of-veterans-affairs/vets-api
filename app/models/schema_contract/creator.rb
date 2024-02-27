# frozen_string_literal: true

module SchemaContract
  class Creator
    def self.call(user:, response:, test_name:)
      if response.success? && Flipper.enabled?("schema_contract_#{test_name}")
        return if SchemaContract::Validation.where(contract_name: test_name, created_at: Time.zone.today.all_day).any?

        record = SchemaContract::Validation.create(
          contract_name: test_name, user_uuid: user.uuid, response: response.to_json, status: 'initiated'
        )

        UpstreamSchemaValidationJob.perform_async(record.id)
      end
    rescue => e
      # blanket rescue to avoid this code blocking execution
      message = { response:, test_name:, error_details: e.message }
      Rails.logger.error('Error creating schema contract job', message)
    end
  end
end
