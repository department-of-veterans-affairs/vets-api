# frozen_string_literal: true

module SchemaContract
  class Runner
    def self.run(user:, response:, test_name:)
      if response.success? && Flipper.enabled?("schema_contract_#{test_name}")
        record = SchemaContract.find_by(name: test_name)

        if record
          beginning_of_today = Time.zone.today.beginning_of_day
          return if record.last_updated >= beginning_of_today

          record.update(last_user_uuid: user.uuid, last_response: response.to_json)
        else
          record = SchemaContract.create(
            name: 'get_appointments', schema: "#{Settings.schema_contract.appointments_index.path}_#{test_name}.json",
            last_user_uuid: user.uuid, last_response: response.to_json
          )
        end

        UpstreamSchemaValidationJob.perform_async(record.id)
      end
    end
  end
end