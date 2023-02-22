# frozen_string_literal: true

module MockedAuthentication
  module Routing
    extend ActiveSupport::Concern
    include MockedAuthentication::Engine.routes.url_helpers

    included do
      def default_url_options
        Rails.application.routes.default_url_options
      end
    end
  end
end
