# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class TravelPayClaimSummary < Common::Resource
      attribute :id, Types::String
      attribute :claimNumber, Types::String
      attribute :claimStatus, Types::String
      attribute :appointmentDateTime, Types::DateTime
      attribute :facilityId, Types::String
      attribute :facilityName, Types::String
      attribute :totalCostRequested, Types::Decimal
      attribute :reimbursementAmount, Types::Decimal
      attribute :createdOn, Types::DateTime
      attribute :modifiedOn, Types::DateTime
    end
  end
end
