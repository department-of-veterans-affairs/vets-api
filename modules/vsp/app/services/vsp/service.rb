# frozen_string_literal: true

module Vsp
  class Service < Common::Client::Base
    configuration Vsp::Configuration

    def get_message
      response = perform(:get, '/', {})
      Appeals::Responses::Appeals.new(response.body, response.status)
    end
  end
end
