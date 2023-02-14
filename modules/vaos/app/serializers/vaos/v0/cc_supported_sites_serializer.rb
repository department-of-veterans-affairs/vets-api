# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
require 'fast_jsonapi'

module VAOS
  module V0
    class CCSupportedSitesSerializer
      include FastJsonapi::ObjectSerializer

      set_id :id

      set_type :object_type

      attributes :name,
                 :timezone
    end
  end
end
# :nocov:
