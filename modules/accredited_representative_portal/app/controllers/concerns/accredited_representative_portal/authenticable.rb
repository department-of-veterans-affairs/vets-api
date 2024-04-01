# frozen_string_literal: true

module AccreditedRepresentativePortal
  module Authenticable
    extend ActiveSupport::Concern

    included do
      prepend SignIn::Authentication
    end

    private

    def load_user_object
      RepresentativeUserLoader.new(access_token:, request_ip: request.remote_ip).perform
    rescue AccreditedRepresentativePortal::Errors::StandardError => e
      handle_authenticate_error(e)
    end
  end
end
