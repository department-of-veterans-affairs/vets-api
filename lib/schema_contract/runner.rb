# frozen_string_literal: true

module SchemaContract
  class Runner
    def self.run(user:, response:, test_name:)
      if response.success? && Flipper.enabled?("schema_contract_#{test_name}")
        record = SchemaContract.find_by(name: test_name)

        if record
          beginning_of_today = Time.zone.today.beginning_of_day
          return if record.last_updated >= beginning_of_today

          record.update(last_user_uuid: user.uuid, last_response: response.to_json, last_run_initiated: Time.zone.now)
        else
          record = SchemaContract.create(
            name: 'get_appointments', last_user_uuid: user.uuid, last_response: response.to_json,
            last_run_initiated: Time.zone.now
          )
        end

        UpstreamSchemaValidationJob.perform_async(record.test_name)
      end
    end
  end
end