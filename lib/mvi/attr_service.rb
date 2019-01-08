module MVI
  class AttrService < Service
    configuration MVI::Configuration

    private

    def create_profile_message(user_attributes)
      message_user_attributes(user_attributes)
    end

    def measure_info(_user_attributes)
      Rails.logger.measure_info('Performed MVI Query') { yield }
    end
  end
end
