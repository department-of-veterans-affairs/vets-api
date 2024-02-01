# frozen_string_literal: true

module SchemaContract
  class Runner
    def self.run(user:, response:, flag:, test_name:, schema:)
      if response.success? && Flipper.enabled?(flag)
        record = SchemaContract.find_by(name: test_name)

        if record
          beginning_of_today = Time.zone.today.beginning_of_day
          return if record.last_updated >= beginning_of_today

          record.update(last_user_uuid: user.uuid, last_response: response.to_json)
        else
          record = SchemaContract.create(
            name: 'get_appointments', schema:,
            last_user_uuid: user.uuid, last_response: response.to_json
          )
        end

        UpstreamSchemaValidationJob.perform_async(record.id)
      end
    end
  end
end