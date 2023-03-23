# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    module FactoryTypes
      def patient_type
        {
          user:,
          resource_identifier: 'patient',
          api: Settings.hqva_mobile.lighthouse.health_api
        }
      end

      def questionnaire_type
        {
          user:,
          resource_identifier: 'questionnaire',
          api: Settings.hqva_mobile.lighthouse.pgd_api
        }
      end

      def questionnaire_response_type
        {
          user:,
          resource_identifier: 'questionnaire_response',
          api: Settings.hqva_mobile.lighthouse.pgd_api
        }
      end

      def appointment_type
        {
          user:,
          resource_identifier: 'appointment',
          api: Settings.hqva_mobile.lighthouse.health_api
        }
      end

      def location_type
        {
          user:,
          resource_identifier: 'location',
          api: Settings.hqva_mobile.lighthouse.health_api
        }
      end

      def organization_type
        {
          user:,
          resource_identifier: 'organization',
          api: Settings.hqva_mobile.lighthouse.health_api
        }
      end
    end
  end
end
