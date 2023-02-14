# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
require 'fast_jsonapi'

module VAOS
  module V0
    class CancelReasonSerializer
      include FastJsonapi::ObjectSerializer

      set_id :number
      attributes :number,
                 :text,
                 :type,
                 :inactive
    end
  end
end
# :nocov:
