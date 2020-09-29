# frozen_string_literal: true

require 'fast_jsonapi'

module Mobile
  module V0
    class UserSerializer
      include FastJsonapi::ObjectSerializer

      # TODO: return full set of user profile data see issue here:
      # https://github.com/department-of-veterans-affairs/va.gov-team/issues/13458
      attributes :first_name,
                 :middle_name,
                 :last_name,
                 :email
    end
  end
end
