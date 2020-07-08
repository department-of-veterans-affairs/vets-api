# frozen_string_literal: true

module MVI
  class AttrService < Service
    configuration MVI::AttrConfiguration

    private

    # @param user_attributes [MviUserAttributes]
    def create_profile_message(user_attributes)
      message_user_attributes(user_attributes)
    end

    # @param user_attributes [MviUserAttributes]
    def measure_info(_user_attributes)
      Rails.logger.measure_info('Performed MVI Query') { yield }
    end
  end
end
