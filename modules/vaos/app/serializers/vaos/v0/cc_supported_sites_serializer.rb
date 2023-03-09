# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
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
# :nocov:
