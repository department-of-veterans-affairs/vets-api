# frozen_string_literal: true

module Mobile
  module Routing
    extend ActiveSupport::Concern
    include Mobile::Engine.routes.url_helpers

    included do
      def default_url_options
        Rails.application.routes.default_url_options
      end
    end
  end
end
