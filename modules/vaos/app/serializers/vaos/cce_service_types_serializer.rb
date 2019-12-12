# frozen_string_literal: true

require 'fast_jsonapi'

module VAOS
  class CCEServiceTypesSerializer
    include FastJsonapi::ObjectSerializer

    set_id :name
    attributes :name,
               :patient_friendly_name
  end
end
