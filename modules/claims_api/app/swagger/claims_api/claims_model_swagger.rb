# frozen_string_literal: true

module ClaimsApi
  class ClaimsModelSwagger
    include Swagger::Blocks

    swagger_schema :Claims do
      key :description, 'Claim with some details for the given Veteran info'

      property :id do
        key :type, :string
        key :example, '8347210'
        key :description, 'Claim ID from EVSS'
      end

      property :type do
        key :type, :string
        key :example, 'evss_claims'
        key :description, 'Required by JSON API standard'
      end

      property :attributes do
        key :type, :object
        key :description, 'Required by JSON API standard'

        property :date_filed do
          key :type, :string
          key :format, 'date'
          key :example, '2018-06-04'
          key :description, 'Date in YYYY-MM-DD the claim was first filed'
        end

        property :min_est_date do
          key :type, :string
          key :format, 'date'
          key :example, '2019-06-04'
          key :description, 'Minimum Estimated Claim Completion Date'
        end

        property :max_est_date do
          key :type, :string
          key :format, 'date'
          key :example, '2019-09-04'
          key :description, 'Maximum Estimated Claim Completion Date'
        end

        property :open do
          key :type, :boolean
          key :example, true
          key :description, 'Has the claim been resolved'
        end

        property :waiver_submitted do
          key :type, :boolean
          key :example, false
          key :description, 'Requested Decision or Waiver 5103 Submitted'
        end

        property :documents_needed do
          key :type, :boolean
          key :example, false
          key :description, 'Does the claim require additional documents to be submitted'
        end

        property :development_letter_sent do
          key :type, :boolean
          key :example, false
          key :description, 'Indicates if a Development Letter has been sent to the Claimant regarding a benefit claim'
        end

        property :decision_letter_sent do
          key :type, :boolean
          key :example, false
          key :description, 'Indicates if a Decision Letter has been sent to the Claimant regarding a benefit claim'
        end

        property :updated_at do
          key :type, :string
          key :format, 'date-time'
          key :example, '2018-07-30T17:31:15.958Z'
          key :description, 'Time stamp of last change to the claim'
        end

        property :status do
          key :type, :string
          key :example, 'Claim recieved'
          key :description, 'Current status of the claim (See API description for more details)'
          key :enum, [
            'Claim recieved',
            'Initial review',
            'Evidence gathering, review, and decision',
            'Preparation for notification',
            'Complete'
          ]
        end

        property :requested_decision do
          key :type, :boolean
          key :example, false
          key :description, 'The claim filer has requested a claim decision be made'
        end

        property :claim_type do
          key :type, :string
          key :example, 'Compensation'
          key :description, 'The type of claim originally submitted'
          key :enum, [
            'Compensation',
            'Compensation and Pension',
            'Dependency'
          ]
        end
      end
    end
  end
end
