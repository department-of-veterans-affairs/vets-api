# frozen_string_literal: true

require 'fast_jsonapi'

module VAOS
  class CCSupportedSitesSerializer
    include FastJsonapi::ObjectSerializer

    set_id :id

    set_type :object_type

    attributes :name,
               :timezone
  end
end
