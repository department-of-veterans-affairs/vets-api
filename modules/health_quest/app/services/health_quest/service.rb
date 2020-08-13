# frozen_string_literal: true

module HealthQuest
  class Service < Common::Client::Base
    configuration HealthQuest::Configuration

    def get_message
      response = perform(:get, '/', {})
      Resource.new(response.body.symbolize_keys)
    end
  end
end
