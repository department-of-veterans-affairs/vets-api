# frozen_string_literal: true

module MyHealth
  module Concerns
    module MHVControllerConcerns
      extend ActiveSupport::Concern

      included do
        before_action :authorize
        before_action :authenticate_client
      end

      protected

      def authenticate_client
        client.authenticate if client.session.expired?
      end
    end
  end
end
