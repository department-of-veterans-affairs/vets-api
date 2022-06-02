# frozen_string_literal: true

module Mobile
  module V0
    module Contracts
      class FacilityEligibility < PaginationBase
        params do
          optional(:service_type).maybe(:string, :filled?)
          optional(:facility_ids).maybe(:array, :filled?)
          optional(:type).maybe(:string, :filled?)
        end
      end
    end
  end
end
