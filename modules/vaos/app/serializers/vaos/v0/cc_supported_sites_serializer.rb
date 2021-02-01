# frozen_string_literal: true

require 'jsonapi/serializer'

module VAOS
  module V0
    class CCSupportedSitesSerializer
      include JSONAPI::Serializer

      set_id :id

      set_type :object_type

      attributes :name,
                 :timezone
    end
  end
end
