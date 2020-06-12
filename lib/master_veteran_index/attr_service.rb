# frozen_string_literal: true

require_relative 'service'
require_relative 'attr_configuration'

module MasterVeteranIndex
  class AttrService < MasterVeteranIndex::Service
    configuration MasterVeteranIndex::AttrConfiguration

    private

    def create_profile_message(user_attributes)
      message_user_attributes(user_attributes)
    end

    def measure_info(_user_attributes)
      Rails.logger.measure_info('Performed MVI Query') { yield }
    end
  end
end
