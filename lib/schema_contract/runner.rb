# frozen_string_literal: true

module SchemaContract
  class Runner
    def self.run(user:, response:, test_name:)
      if response.success? && Flipper.enabled?("schema_contract_#{test_name}")
        return if SchemaContractTest.where(name: test_name, created_at: Time.zone.today.all_day).any?

        record = SchemaContractTest.create(
          name: test_name, last_user_uuid: user.uuid, last_response: response.to_json,
          status: 'initiated'
        )

        UpstreamSchemaValidationJob.perform_async(record.id)
      end
    end
  end
end