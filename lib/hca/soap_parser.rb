# frozen_string_literal: true

module HCA
  class SOAPParser < Common::Client::Middleware::Response::SOAPParser
    def on_complete(env)
      super
    end
  end
end
