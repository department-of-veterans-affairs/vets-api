# frozen_string_literal: true

module Vsp
  class Service < Common::Client::Base
    configuration Vsp::Configuration

    def get_message
      response = perform(:get, '/')
      Vsp::MessageResponse.new(response.body.symbolize_keys)
    end
  end
end
