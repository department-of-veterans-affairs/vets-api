# frozen_string_literal: true

module Avs
  class V0::Schemas::Avs
    include Swagger::Blocks

    # rubocop:disable Metrics/BlockLength
    swagger_schema :Avs do
      key :required, [:data]

      property :id, type: :string, example: '9A7AF40B2BC2471EA116891839113252'
      property :type, type: :string, example: 'AfterVisitSummary'

      property :attributes, type: :object do
        property :appointmentIens, type: :array do
          items type: :string
        end
        property :meta, type: :object do
          property :generatedDate, type: :string
          property :pageHeader, type: :string
          property :stationNo, type: :string
          property :timeZone, type: :string
        end
        property :clinicsVisited do
          key :$ref, :clinicVisited
        end
        property :providers, type: :array do
          items type: :string
        end
        property :reasonForVisit, type: :array do
          items do
            key :$ref, :reasonForVisit
          end
        end
        property :diagnoses, type: :array do
          items do
            key :$ref, :diagnosis
          end
        end
        property :vitals, type: :array do
          items do
            key :$ref, :vital
          end
        end
        property :orders, type: :array do
          items do
            key :$ref, :order
          end
        end
        property :procedures, type: :array do
          items do
            key :$ref, :procedure
          end
        end
        property :immunizations, type: :array do
          items do
            key :$ref, :immunization
          end
        end
        property :appointments, type: :array do
          items do
            key :$ref, :appointment
          end
        end
        property :patientInstructions, type: :string
        property :patientEducation, type: :string
        property :pharmacyTerms, type: :array do
          items do
            key :$ref, :pharmacyTerm
          end
        end
        property :primaryCareProviders, type: :array do
          items type: :string
        end
        property :primaryCareTeam, type: :string
        property :primaryCareTeamMembers, type: :array do
          items do
            key :$ref, :primaryCareTeamMember
          end
        end
        property :problems, type: :array do
          items do
            key :$ref, :problem
          end
        end
        property :clinicalReminders, type: :array do
          items do
            key :$ref, :clinicalReminder
          end
        end
        property :clinicalServices, type: :array do
          items do
            key :$ref, :clinicalService
          end
        end
        property :allergiesReactions, type: :object do
          property :T, type: :string
          property :noAllergyAssessment, type: :boolean
          property :noKnownAllergies, type: :boolean
          property :allergies, type: :array do
            items do
              key :$ref, :allergy
            end
          end
        end
        property :clinicMedications, type: :array do
          items do
            key :$ref, :medication
          end
        end
        property :vaMedications, type: :array do
          items do
            key :$ref, :medication
          end
        end
        property :nonvaMedications, type: :array do
          items do
            key :$ref, :medication
          end
        end
        property :medChangesSummary, type: :object do
          property :discontinuedMeds, type: :array do
            items type: :string
          end
          property :newMedications, type: :array do
            items type: :string
          end
          property :changedMedications, type: :array do
            items type: :string
          end
        end
        property :labResults, type: :array do
          items do
            key :$ref, :labResult
          end
        end
        property :discreteData, type: :array do
          items do
            key :$ref, :discreteDataItem
          end
        end
        property :radiologyReports1Yr, type: :string
        property :moreHelpAndInformation, type: :string
      end
    end
    # rubocop:enable Metrics/BlockLength

    swagger_schema :clinicVisited do
      property :T, type: :string
      property :date, type: :string
      property :time, type: :integer
      property :clinic, type: :string
      property :clinicIen, type: :string
      property :provider, type: :string
      property :site, type: :string
      property :patientFriendlyName, type: :string
      property :physicalLocation, type: :string
      property :visitString, type: :string
      property :appointmentIen, type: :string
      property :appointmentType, type: :string
      property :resourceIen, type: :string
      property :requestIen, type: :string
      property :status, type: :string
    end

    swagger_schema :reasonForVisit do
      property :T, type: :string
      property :diagnosis, type: :string
      property :code, type: :string
    end

    swagger_schema :diagnosis do
      property :T, type: :string
      property :diagnosis, type: :string
      property :code, type: :string
    end

    swagger_schema :vital do
      property :T, type: :string
      property :type, type: :string
      property :value, type: :string
      property :date, type: :string
      property :qualifiers, type: :string
    end

    swagger_schema :order do
      property :T, type: :string
      property :type, type: :string
      property :date, type: :string
      property :text, type: :string
    end

    swagger_schema :procedure do
      property :code, type: :string
      property :name, type: :string
    end

    swagger_schema :immunization do
      property :T, type: :string
      property :date, type: :string
      property :name, type: :string
      property :facility, type: :string
    end

    swagger_schema :appointment do
      property :T, type: :string
      property :site, type: :string
      property :stationNo, type: :string
      property :location, type: :string
      property :datetime, type: :string
      property :fmDatetime, type: :number
      property :type, type: :string
      property :physicalLocation, type: :string
    end

    swagger_schema :pharmacyTerm do
      property :type, type: :string
      property :term, type: :string
      property :aka, type: :string
      property :explanation, type: :string
      property :patientActions, type: :string
    end

    swagger_schema :primaryCareTeamMember do
      property :T, type: :string
      property :name, type: :string
      property :title, type: :string
    end

    swagger_schema :problem do
      property :dfn, type: :string
      property :ien, type: :string
      property :status, type: :string
      property :description, type: :string
      property :code, type: :string
      property :onsetDateStr, type: :string
      property :onsetDate, type: :string
      property :lastUpdatedStr, type: :string
      property :lastUpdated, type: :string
      property :scStatus, type: :string
      property :scConditions, type: :string
      property :detailRpc, type: :string
      property :transcribed, type: :boolean
      property :locationIen, type: :number
      property :location, type: :string
      property :locationType, type: :string
      property :providerIen, type: :string
      property :provider, type: :string
      property :serviceIen, type: :string
      property :service, type: :string
      property :version, type: :string
      property :comments, type: :string
    end

    swagger_schema :clinicalReminder do
      property :ien, type: :string
      property :whenDue, type: :string
      property :lastOccurrence, type: :string
      property :name, type: :string
      property :frequency, type: :string
    end

    swagger_schema :clinicalService do
      property :stationNo, type: :string
      property :name, type: :string
      property :location, type: :string
      property :hours, type: :string
      property :phone, type: :string
      property :comment, type: :string
    end

    swagger_schema :allergy do
      property :T, type: :string
      property :allergen, type: :string
      property :reactions, type: :array do
        items type: :string
      end
      property :severity, type: :string
      property :site, type: :string
      property :stationNo, type: :string
      property :type, type: :string
      property :verifiedDate, type: :string
    end

    swagger_schema :medication do
      property :medId, type: :string
      property :name, type: :string
      property :type, type: :string
      property :sig, type: :string
      property :source, type: :string
      property :totalNumRefills, type: :integer
      property :refillsRemaining, type: :integer
      property :startDate, type: :string
      property :stopDate, type: :string
      property :dateExpires, type: :string
      property :dateLastFilled, type: :string
      property :dateLastReleased, type: :string
      property :fmDateLastReleased, type: :integer
      property :stationName, type: :string
      property :stationNo, type: :string
      property :provider, type: :string
      property :description, type: :string
      property :ndc, type: :string
      property :statusIen, type: :string
      property :status, type: :string
      property :discontinuedDate, type: :string
      property :fmDiscontinuedDate, type: :integer
      property :comment, type: :string
      property :documentor, type: :string
      property :documentingFacility, type: :string
      property :quantity, type: :integer
      property :daysSupply, type: :integer
      property :orderingProvider, type: :string
      property :fillingPharmacy, type: :string
      property :facilityPhone, type: :string
      property :rxNumber, type: :string
      property :prescriptionType, type: :string
      property :patientTaking, type: :boolean
      property :current, type: :string
      property :remote, type: :string
      property :dateDocumented, type: :string
      property :fmIssueDate, type: :integer
    end

    swagger_schema :labResult do
      property :T, type: :string
      property :specimen, type: :string
      property :collectionDatetime, type: :string
      property :performingLab, type: :string
      property :orderingProvider, type: :string
      property :values, type: :array do
        items do
          key :$ref, :labResultValue
        end
      end
    end

    swagger_schema :labResultValue do
      property :T, type: :string
      property :test, type: :string
      property :result, type: :string
      property :units, type: :string
      property :flag, type: :string
      property :refRange, type: :string
    end

    swagger_schema :discreteDataItem do
      property :temp, type: :array do
        items do
          key :$ref, :discreteItem
        end
      end
    end

    swagger_schema :discreteItem do
      property :T, type: :string
      property :datetime, type: :string
      property :fmDate, type: :number
      property :value, type: :string
    end
  end
end
