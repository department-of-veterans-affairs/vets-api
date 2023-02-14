# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
require 'fast_jsonapi'

module VAOS
  module V0
    class DirectBookingEligibilityCriteriaSerializer
      include FastJsonapi::ObjectSerializer

      attributes :id,
                 :created_date,
                 :last_modified_date,
                 :created_by,
                 :modified_by,
                 :core_settings,
                 :object_type,
                 :link
    end
  end
end
# :nocov:
