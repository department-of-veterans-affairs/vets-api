# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
require 'fast_jsonapi'

module VAOS
  module V0
    class SystemSerializer
      include FastJsonapi::ObjectSerializer

      set_id :unique_id
      attributes :unique_id,
                 :assigning_authority,
                 :assigning_code,
                 :id_status
    end
  end
end
# :nocov:
