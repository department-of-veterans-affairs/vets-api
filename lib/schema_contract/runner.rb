# frozen_string_literal: true

module SchemaContract
  class Runner
    def self.run(user:, response:, test_name:)
      if response.success? && Flipper.enabled?("schema_contract_#{test_name}")
        return if SchemaContractTest.where(name: test_name, created_at: Time.zone.today.all_day).any?

        record = SchemaContractTest.create(name: test_name, user_uuid: user.uuid, response: response.to_json,status: 'initiated')

        UpstreamSchemaValidationJob.perform_async(record.id)
      end
    rescue => e
      # blanket rescue to avoid this code blocking execution
      message = { user:, response:, test_name:, error_details: e}
      Rails.logger.error('Error creating schema contract job', message)
    end
  end
end