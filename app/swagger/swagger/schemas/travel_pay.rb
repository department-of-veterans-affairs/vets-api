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
        'Pre Approved For Payment',
        'Saved',
        'In Process',
        'Pending',
        'On Hold',
        'In Manual Review',
        'Submitted For Payment',
        'Claim Paid',
        'Incomplete',
        'Appeal',
        'Denied',
        'Closed With No Payment',
        'Claim Submitted',
        'Approved For Payment',
        'Approved For Payment Incomplete',
        'Payment Canceled',
        'Partial Payment',
        'Fiscal Rescinded',
        'Unspecified'
      ], example: 'Claim Paid'
      property :appointmentDateTime, type: :string, example: '2024-06-13T13:57:07.291Z'
      property :facilityName, type: :string, example: 'Cheyenne VA Medical Center'
      property :createdOn, type: :string, example: '2024-06-13T13:57:07.291Z'
      property :modifiedOn, type: :string, example: '2024-06-13T13:57:07.291Z'
    end
  end
end
