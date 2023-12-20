# frozen_string_literal: true

require 'va_profile/health_benefit/configuration'
require 'va_profile/health_benefit/associated_persons_response'
require 'va_profile/models/associated_person'

module VAProfile
  module HealthBenefit
    class Service < VAProfile::Service
      include Common::Client::Concerns::Monitoring

      configuration VAProfile::HealthBenefit::Configuration

      OID = '1.2.3' # placeholder

      attr_reader :user

      def get_associated_persons
        return mock_get_associated_persons if config.mock_enabled?

        with_monitoring do
          response = perform(:get, v1_read_path)
          VAProfile::HealthBenefit::AssociatedPersonsResponse.from(response)
        end
      rescue => e
        handle_error(e)
      end

      def mock_get_associated_persons
        fixture_path = %w[spec fixtures va_profile health_benefit_v1_associated_persons.json]
        body = Rails.root.join(*fixture_path).read
        response = OpenStruct.new(status: 200, body:)
        VAProfile::HealthBenefit::AssociatedPersonsResponse.from(response)
      end

      def get_relationship_types
        with_monitoring do
          response = perform(:get, relationship_types_path)
          VAProfile::HealthBenefit::RelationshipTypesResponse.from(response)
        end
      rescue => e
        handle_error(e)
      end

      private

      ID_ME_AAID = '^PN^200VIDM^USDVA'
      LOGIN_GOV_AAID = '^PN^200VLGN^USDVA'

      def csp_id
        user&.idme_uuid || user&.logingov_uuid
      end

      def aaid
        ID_ME_AAID if user&.idme_uuid.present?
        LOGIN_GOV_AAID if user&.logingov_uuid.present?
      end

      def id_with_aaid
        "#{csp_id}#{aaid}"
      end

      def identity_path
        encoded_id_with_aaid = ERB::Util.url_encode(id_with_aaid)
        "#{OID}/#{encoded_id_with_aaid}"
      end

      def v1_read_path
        "#{config.base_path}/health-benefit/v1/#{identity_path}/read"
      end

      def relationship_types_path
        "#{config.base_path}/referencedata/v1/associated-person/relationship-type"
      end
    end
  end
end
