# frozen_string_literal: true

module VAOS
  class Service < Common::Client::Base
    configuration VAOS::Configuration

    def get_message
      response = perform(:get, '/', {})
      Resource.new(response.body.symbolize_keys)
    end
  end
end
