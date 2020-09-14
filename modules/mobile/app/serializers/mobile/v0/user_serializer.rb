# frozen_string_literal: true

require 'fast_jsonapi'

module Mobile
  module V0
    class UserSerializer
      include FastJsonapi::ObjectSerializer

      attributes :first_name,
                 :middle_name,
                 :last_name,
                 :email
    end
  end
end
