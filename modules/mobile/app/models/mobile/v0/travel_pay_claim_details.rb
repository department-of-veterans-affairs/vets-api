# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class TravelPayClaimDetails < Common::Resource
      attribute :id, Types::String
      attribute :claimNumber, Types::String.optional
      attribute :claimName, Types::String.optional
      attribute :claimantFirstName, Types::String.optional
      attribute :claimantMiddleName, Types::String.optional
      attribute :claimantLastName, Types::String.optional
      attribute :claimStatus, Types::String
      attribute :appointmentDate, Types::DateTime
      attribute :facilityName, Types::String.optional
      attribute :totalCostRequested, Types::Decimal.optional
      attribute :reimbursementAmount, Types::Decimal.optional
      attribute :rejectionReason, Types::Hash.optional
      attribute :decisionLetterReason, Types::String.optional
      attribute :createdOn, Types::DateTime
      attribute :modifiedOn, Types::DateTime
      attribute :appointment, Types::Hash.optional
      attribute :expenses, Types::Array.optional
      attribute :documents, Types::Array.optional
    end
  end
end
