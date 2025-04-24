# frozen_string_literal: true

module MyHealth
  module V1
    module MedicalRecords
      class SelfEnteredController < ApplicationController
        include MyHealth::MHVControllerConcerns
        service_tag 'mhv-medical-records'

        def index
          render json: client.get_all_sei_data.to_json
        end

        def vitals
          render json: client.get_sei_vital_signs_summary.to_json
        end

        def allergies
          render json: client.get_sei_allergies.to_json
        end

        def family_history
          render json: client.get_sei_family_health_history.to_json
        end

        def vaccines
          render json: client.get_sei_immunizations.to_json
        end

        def test_entries
          render json: client.get_sei_test_entries.to_json
        end

        def medical_events
          render json: client.get_sei_medical_events.to_json
        end

        def military_history
          render json: client.get_sei_military_history.to_json
        end

        def providers
          render json: client.get_sei_healthcare_providers.to_json
        end

        def health_insurance
          render json: client.get_sei_health_insurance.to_json
        end

        def treatment_facilities
          render json: client.get_sei_treatment_facilities.to_json
        end

        def food_journal
          render json: client.get_sei_food_journal.to_json
        end

        def activity_journal
          render json: client.get_sei_activity_journal.to_json
        end

        def medications
          render json: client.get_sei_medications.to_json
        end

        def emergency_contacts
          render json: client.get_sei_emergency_contacts.to_json
        end

        protected

        def client
          @client ||= BBInternal::Client.new(session: { user_id: current_user.mhv_correlation_id,
                                                        icn: current_user.icn })
        end

        def authorize
          raise_access_denied if current_user.mhv_correlation_id.is_blank? || current_user.icn.is_blank?
        end

        def raise_access_denied
          raise Common::Exceptions::Forbidden, detail: 'You do not have access to self-entered information'
        end
      end
    end
  end
end
