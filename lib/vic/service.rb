# frozen_string_literal: true

module VIC
  class Service < Common::Client::Base
    configuration VIC::Configuration

    def submit(_form)
      {
        confirmation_number: SecureRandom.uuid
      }
    end
  end
end
