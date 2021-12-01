# frozen_string_literal: true

require_relative 'service'
require_relative 'attr_configuration'

module MPI
  class AttrService < Service
    configuration MPI::AttrConfiguration

    private

    def create_profile_message(user_attributes, search_type: MPI::Constants::CORRELATION_WITH_RELATIONSHIP_DATA)
      message_user_attributes(user_attributes, search_type)
    end

    def measure_info(_user_attributes, &block)
      Rails.logger.measure_info('Performed MVI Query', &block)
    end
  end
end
