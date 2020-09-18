# frozen_string_literal: true

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
