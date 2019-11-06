# frozen_string_literal: true

module VAOS
  module Headers
    extend ActiveSupport::Concern

    private

    def headers(user)
      { 'Referer' => 'https://api.va.gov', 'X-VAMF-JWT' => user_service.session(user) }
    end

    def user_service
      VAOS::UserService.new
    end
  end
end
