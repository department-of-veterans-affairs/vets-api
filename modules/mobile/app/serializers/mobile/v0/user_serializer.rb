# frozen_string_literal: true

require 'fast_jsonapi'

module Mobile
  module V0
    class UserSerializer
      include FastJsonapi::ObjectSerializer

      # TODO: return full set of user data, including latest appeals, claims, and appointments
      attributes :first_name,
                 :middle_name,
                 :last_name,
                 :email
    end
  end
end
