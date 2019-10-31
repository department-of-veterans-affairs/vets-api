# frozen_string_literal: true

module VAOS
  module Headers
    extend ActiveSupport::Concern

    private

    def headers(user)
      { 'Referer' => 'https://api.va.gov', 'X-VAMF-JWT' => VAOS::JWT.new(user).token }
    end
  end
end
