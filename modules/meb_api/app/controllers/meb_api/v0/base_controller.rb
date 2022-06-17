# frozen_string_literal: true

module MebApi
  module V0
    class BaseController < ::ApplicationController
      protected

      def check_flipper
        routing_error unless Flipper.enabled?(:show_meb_mock_endpoints)
      end

      def check_toe_flipper
        routing_error unless Flipper.enabled?(:show_updated_toe_app)
      end
    end
  end
end
