# frozen_string_literal: true

module AppealsApi
  module V2
    module Schemas
      class LegacyAppeals
        include Swagger::Blocks

        swagger_component do
          schema :legacyAppeal do
            property :assignedAttorney do
              key :type, :string
            end

            property :assignedJudge do
              key :type, :string
            end

            property :readableHearingRequestType do
              key :type, :string
            end

            property :readableOriginalHearingRequestType do
              key :type, :string
            end

            property :issues do
              key :type, :array
              items do
                property :levels do
                  key :type, :array
                  items do
                    key :type, :string
                    key :example, 'Schedular'
                  end
                end

                property :program, type: :string, example: '02'
                property :type, type: :string, example: '12'
                property :codes do
                  items do
                    key :type, :string
                    key :example, '04'
                  end
                end
                property :disposition, type: :string, example: 'F'
                property :close_date, type: :date
                property :note, type: :string, example: 'Aut temporibus non sit eum.'
                property :vacols_sequence_id, type: :integer, example: 7
                property :labels do
                  key :type, :array
                  items do
                    key :type, :string
                    key :example, 'Compensation'
                  end
                end
                property :readjudication, type: :boolean, example: false
                property :reasons, type: :array, example: []
              end
            end

            property :hearings do
              key :type, :string
            end

            property :completedHearingOnPreviousAppeal? do
              key :type, :string
            end

            property :appellantIsNotVeteran do
              key :type, :string
            end

            property :appellantFullName do
              key :type, :string
            end

            property :appellantAddress do
              key :type, :string
            end

            property :appellantTz do
              key :type, :string
            end

            property :appellantRelationship do
              key :type, :string
            end

            property :assignedToLocation do
              key :type, :string
            end

            property :vbmsId do
              key :type, :string
            end

            property :veteranFullName do
              key :type, :string
            end

            property :veteranDeathDate do
              key :type, :string
            end

            property :veteranAppellantDeceased do
              key :type, :string
            end

            property :veteranFileNumber do
              key :type, :string
            end

            property :externalId do
              key :type, :string
            end

            property :type do
              key :type, :string
            end

            property :aod do
              key :type, :string
            end

            property :docketNumber do
              key :type, :string
            end

            property :docketRangeDate do
              key :type, :string
            end

            property :status do
              key :type, :string
            end

            property :decisionDate do
              key :type, :string
            end

            property :form9Date do
              key :type, :string
            end

            property :nodDate do
              key :type, :string
            end

            property :certificationDate do
              key :type, :string
            end

            property :paperCase do
              key :type, :string
            end

            property :overtime do
              key :type, :string
            end

            property :caseflowVeteranId do
              key :type, :string
            end

            property :socDate do
              key :type, :string
            end

            property :closestRegionalOffice do
              key :type, :string
            end

            property :closestRegionalOfficeLabel do
              key :type, :string
            end

            property :availableHearingLocations do
              key :type, :string
            end

            property :docketName do
              key :type, :string
            end

            property :regionalOffice do
              key :type, :string
            end

            property :documentId do
              key :type, :string
            end

            property :canEditDocumentId do
              key :type, :string
            end

            property :attorneyCaseReviewId do
              key :type, :string
            end
          end
        end
      end
    end
  end
end
