# frozen_string_literal: true

module MyHealth
  module V1
    module MedicalRecords
      class SelfEnteredController < MrController
        def vitals
          render json: bb_client.get_sei_vital_signs_summary.to_json
        end

        def allergies
          render json: bb_client.get_sei_allergies.to_json
        end

        def family_history
          render json: bb_client.get_sei_family_health_history.to_json
        end

        def vaccines
          render json: bb_client.get_sei_immunizations.to_json
        end

        def test_entries
          render json: bb_client.get_sei_test_entries.to_json
        end

        def medical_events
          render json: bb_client.get_sei_medical_events.to_json
        end

        def military_history
          render json: bb_client.get_sei_military_history.to_json
        end

        def providers
          render json: bb_client.get_sei_healthcare_providers.to_json
        end

        def health_insurance
          render json: bb_client.get_sei_health_insurance.to_json
        end

        def treatment_facilities
          render json: bb_client.get_sei_treatment_facilities.to_json
        end

        def food_journal
          render json: bb_client.get_sei_food_journal.to_json
        end

        def activity_journal
          render json: bb_client.get_sei_activity_journal.to_json
        end

        def medications
          render json: bb_client.get_sei_medications.to_json
        end

        def emergency_contacts
          render json: bb_client.get_sei_emergency_contacts.to_json
        end
      end
    end
  end
end
