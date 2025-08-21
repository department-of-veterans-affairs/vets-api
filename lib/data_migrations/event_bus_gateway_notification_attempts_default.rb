# frozen_string_literal: true

# TODO: delete after running

module DataMigrations
  module EventBusGatewayNotificationAttemptsDefault
    module_function

    def run
      # rubocop:disable Rails/SkipsModelValidations
      EventBusGatewayNotification.where(attempts: nil).update_all(attempts: 1)
      # rubocop:enable Rails/SkipsModelValidations
    end
  end
end
