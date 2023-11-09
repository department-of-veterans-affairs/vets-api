# frozen_string_literal: true

module MyHealth
  module MHVControllerConcerns
    extend ActiveSupport::Concern

    included do
      before_action :authorize
      before_action :authenticate_client
    end

    protected

    def authenticate_client
      # The authenticate method checks whether the session is expired or incomplete before authenticating.
      client.authenticate
    end
  end
end
