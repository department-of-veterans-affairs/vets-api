# frozen_string_literal: true

module SchemaContract
  class Runner
    def self.run(user:, response:, test_name:)
      if response.success? && Flipper.enabled?("schema_contract_#{test_name}")
        beginning_of_today = Time.zone.today.beginning_of_day
        record = SchemaContract.where(name: test_name, created_at: "created_at >= #{beginning_of_today}").limit(1)
        return if record

        record = SchemaContract.create(
          name: test_name, last_user_uuid: user.uuid, last_response: response.to_json,
          status: 'initiated'
        )

        UpstreamSchemaValidationJob.perform_async(record.id)
      end
    end
  end
end