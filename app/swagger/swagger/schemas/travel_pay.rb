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

    swagger_schema :TravelPayClaimDetails do
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
      property :appointmentDate, type: :string, example: '2024-06-13T13:57:07.291Z'
      property :claimName, type: :string, example: 'Claim created for NOLLE BARAKAT'
      property :claimantFirstName, type: :string, example: 'Nolle'
      property :claimantMiddleName, type: :string, example: 'Polite'
      property :claimantLastName, type: :string, example: 'Varakat'
      property :facilityName, type: :string, example: 'Cheyenne VA Medical Center'
      property :totalCostRequested, type: :number, example: 20.00
      property :reimbursementAmount, type: :number, example: 14.52
      property :appointment, type: :object do
        key :$ref, :TravelPayAppointment
      end
      property :expenses, type: :array do
        items do
          key :$ref, :TravelPayExpense
        end
      end
      property :documents, type: :array do
        items do
          key :$ref, :TravelPayDocumentSummary
        end
      end
      property :createdOn, type: :string, example: '2024-06-13T13:57:07.291Z'
      property :modifiedOn, type: :string, example: '2024-06-13T13:57:07.291Z'
    end

    swagger_schema :TravelPayAppointment do
      property :id, type: :string, example: '33333333-5555-4444-bbbb-222222444444'
      property :appointmentSource, type: :string, example: 'VISTA'
      property :appointmentDateTime, type: :string, example: '2024-06-13T13:57:07.291Z'
      property :appointmentName, type: :string, example: 'VistA - 983 CHY TEST CLINIC'
      property :appointmentType, type: :string, example: 'EnvironmentalHealth'
      property :facilityId, type: :string, example: '33333333-5555-4444-bbbb-222222444444'
      property :facilityName, type: :string, example: 'Cheyenne VA Medical Center'
      property :serviceConnectedDisability, type: :number, example: 421750001 # rubocop:disable Style/NumericLiterals
      property :currentStatus, type: :string, example: 'CHECKED OUT'
      property :appointmentStatus, type: :string, example: 'Complete'
      property :externalAppointmentId, type: :string, example: 'A;3250113.083;1414'
      property :associatedClaimId, type: :string, example: 'TC1234123412341234'
      property :associatedClaimNumber, type: :string, example: 'TC1234123412341234'
      property :isCompleted, type: :boolean, example: true
      property :createdOn, type: :string, example: '2024-06-13T13:57:07.291Z'
      property :modifiedOn, type: :string, example: '2024-06-13T13:57:07.291Z'
    end

    swagger_schema :TravelPayExpense do
      property :id, type: :string, example: '33333333-5555-4444-bbbb-222222444444'
      property :expenseType, type: :string, example: 'Mileage'
      property :name, type: :string, example: 'My trip'
      property :dateIncurred, type: :string, example: '2024-06-13T13:57:07.291Z'
      property :description, type: :string, example: 'mileage-expense'
      property :costRequested, type: :number, example: 20.00
      property :costSubmitted, type: :number, example: 20.00
    end

    swagger_schema :TravelPayDocumentSummary do
      property :documentId, type: :string, example: '33333333-5555-4444-bbbb-222222444444'
      property :filename, type: :string, example: 'DecisionLetter.pdf'
      property :mimetype, type: :string, example: 'application/pdf'
      property :createdon, type: :string, example: '2024-06-13T13:57:07.291Z'
    end

    swagger_schema :TravelPayDocumentBinary do
      property :data, type: :string, example: 'VGhpcyBpcyBhIHN0cmluZw=='
    end
  end
end
