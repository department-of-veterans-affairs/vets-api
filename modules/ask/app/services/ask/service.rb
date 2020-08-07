# frozen_string_literal: true

module Ask
  class Service < Common::Client::Base
    configuration Ask::Configuration

    def get_message
      response = perform(:get, '/', {})
      Resource.new(response.body.symbolize_keys)
    end
  end
end
