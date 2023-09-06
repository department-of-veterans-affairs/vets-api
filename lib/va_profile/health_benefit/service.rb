# frozen_string_literal: true

module VAProfile
  module HealthBenefit
    class Service < VAProfile::Service
      include Common::Client::Concerns::Monitoring

      configuration VAProfile::ContactInformation::Configuration

      OID = '1.2.3'

      attr_reader :user

      def get_next_of_kin
        contact_types = VAProfile::Models::AssociatedPerson.NOK_TYPES
        get_associated_persons.select { |p| contact_types.include?(p.contact_type) }
      end

      def get_emergency_contacts
        contact_types = VAProfile::Models::AssociatedPerson.EC_TYPES
        get_associated_persons.select { |p| contact_types.include?(p.contact_type) }
      end

      def get_associated_persons
        response = perform(:get, v1_read_path)
        VAProfile::HealthBenefit::AssociatedPersonsResponse.new(response.status, response).associated_persons
      end

      def post_emergency_contacts(emergency_contact)
        response = perform(:post, v1_update_path, emergency_contact.in_json)
        VAProfile::HealthBenefit::AssociatedPersonsResponse.new(response.status, response)
      end

      def post_next_of_kin(next_of_kin)
        response = perform(:post, v1_update_path, next_of_kin.in_json)
        VAProfile::HealhtBenefit::AssociatedPersonResponse.new(response.status, response)
      end

      private

      ID_ME_AAID = '^PN^200VIDM^USDVA'
      LOGIN_GOV_AAID = '^PN^200VLGN^USDVA'

      def cps_id
        user&.idme_uuid || user&.logingov_uuid
      end

      def aaid
        return ID_ME_AAID if user&.idme_uuid.present?
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
        "/v1/#{identity_path}/read"
      end

      def v1_update_path
        "/v1/#{identity_path}/update"
      end

      def v1_notification_path
        "/v1/#{identity_path}/notification"
      end
    end
  end
end
