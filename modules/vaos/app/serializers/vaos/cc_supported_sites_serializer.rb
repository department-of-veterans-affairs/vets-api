# frozen_string_literal: true

require 'fast_jsonapi'

module VAOS
  class CCSupportedSitesSerializer
    include FastJsonapi::ObjectSerializer

    set_id :id

    set_type :objectType

    attributes :name,
               :timezone
  end
end

