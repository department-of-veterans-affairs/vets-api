# frozen_string_literal: true

module VAOS
  module Headers
    extend ActiveSupport::Concern

    private

    def headers(user)
      session_token = user_service.session(user)
      { 'Referer' => 'https://api.va.gov', 'X-VAMF-JWT' => session_token }
    end

    def user_service
      VAOS::UserService.new
    end
  end
end
