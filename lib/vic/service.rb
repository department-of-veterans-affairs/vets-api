module VIC
  class Service < Common::Client::Base
    configuration VIC::Configuration

    def submit(form)
      {
        confirmation_number: SecureRandom.uuid
      }
    end
  end
end
