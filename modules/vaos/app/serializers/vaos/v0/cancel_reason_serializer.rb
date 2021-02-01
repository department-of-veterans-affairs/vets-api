# frozen_string_literal: true

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
