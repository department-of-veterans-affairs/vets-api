# frozen_string_literal: true

module DhpConnectedDevices
  module DataMigrations
    module CreateDevices
      module_function

      def run
        Device.where(key: 'fitbit', name: 'Fitbit').first_or_create
      end
    end
  end
end
