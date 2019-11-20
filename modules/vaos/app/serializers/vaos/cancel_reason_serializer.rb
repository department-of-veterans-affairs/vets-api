# frozen_string_literal: true

require 'fast_jsonapi'

module VAOS
  class CancelReasonSerializer
    include FastJsonapi::ObjectSerializer

    set_id :number
    attributes :number,
               :text,
               :type,
               :inactive
  end
end
