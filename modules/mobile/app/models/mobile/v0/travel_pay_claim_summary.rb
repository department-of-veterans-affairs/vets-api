# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class TravelPayClaimSummary < Common::Resource
      attribute :id, Types::String
      attribute :claimNumber, Types::String.optional
      attribute :claimStatus, Types::String
      attribute :appointmentDateTime, Types::DateTime
      attribute :facilityId, Types::String
      attribute :facilityName, Types::String.optional
      attribute :totalCostRequested, Types::Decimal.optional
      attribute :reimbursementAmount, Types::Decimal.optional
      attribute :createdOn, Types::DateTime
      attribute :modifiedOn, Types::DateTime
    end
  end
end
