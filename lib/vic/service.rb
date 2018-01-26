module VIC
  class Service < Common::Client::Base
    configuration VIC::Configuration

    def send_application
      {
        confirmation_number: SecureRandom.uuid
      }
    end
  end
end
