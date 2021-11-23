# frozen_string_literal: true

module MebApi
  module V0
    class BaseController < ::ApplicationController
      before_action :check_flipper

      protected

      def check_flipper
        routing_error unless Flipper.enabled?(:show_meb_mock_endpoints)
      end
    end
  end
end
