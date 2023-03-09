# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
require 'jsonapi/serializer'

module VAOS
  module V0
    class CancelReasonSerializer
      include JSONAPI::Serializer

      set_id :number
      attributes :number,
                 :text,
                 :type,
                 :inactive
    end
  end
end
# :nocov:
