# frozen_string_literal: true

module Swagger::Schemas
  class TravelPay
    include Swagger::Blocks

    swagger_schema :TravelPayClaims do
      key :required, [:data]
      property :data, type: :array do
        items do
          key :$ref, :TravelPayClaimSummary
        end
      end
    end

    swagger_schema :TravelPayClaimSummary do
      property :id, type: :string, example: '33333333-5555-4444-bbbb-222222444444'
      property :claimNumber, type: :string, example: 'TC1234123412341234'
      property :claimStatus, type: :string, enum: [
        'Pre approved for payment',
        'Saved',
        'In process',
        'Pending',
        'On hold',
        'In manual review',
        'Submitted for payment',
        'Claim paid',
        'Incomplete',
        'Appeal',
        'Denied',
        'Closed with no payment',
        'Claim submitted',
        'Approved for payment',
        'Approved for payment incomplete',
        'Payment canceled',
        'Partial payment',
        'Fiscal rescinded',
        'Unspecified'
      ], example: 'Claim paid'
      property :appointmentDateTime, type: :string, example: '2024-06-13T13:57:07.291Z'
      property :facilityName, type: :string, example: 'Cheyenne VA Medical Center'
      property :createdOn, type: :string, example: '2024-06-13T13:57:07.291Z'
      property :modifiedOn, type: :string, example: '2024-06-13T13:57:07.291Z'
    end
  end
end
