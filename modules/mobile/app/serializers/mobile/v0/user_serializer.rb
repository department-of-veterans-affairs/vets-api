# frozen_string_literal: true

require 'fast_jsonapi'

module Mobile
  module V0
    class UserSerializer
      include FastJsonapi::ObjectSerializer

      ADDRESS_KEYS = %i[
        id
        address_line1
        address_line2
        address_line3
        address_pou
        address_type
        city
        country_code
        country_code_iso3
        international_postal_code
        province
        state_code
        zip_code
        zip_code_suffix
      ].freeze

      EMAIL_KEYS = %i[
        id
        email_address
      ].freeze

      PHONE_KEYS = %i[
        id
        area_code
        country_code
        extension
        phone_number
        phone_type
      ].freeze

      SERVICE_DICTIONARY = {
        appeals: :appeals,
        appointments: :vaos,
        claims: :evss,
        directDepositBenefits: %i[evss ppiu],
        disabilityRating: :evss,
        lettersAndDocuments: :evss,
        militaryServiceHistory: :emis,
        paymentHistory: :bgs,
        userProfileUpdate: :vet360,
        secureMessaging: :mhv_messaging,
        scheduleAppointments: :schedule_appointment
      }.freeze

      set_type :user
      attributes :profile, :authorized_services, :health

      attr_reader :user, :facility_names, :contact_info

      # Serializes user data after first fetching user's facility and contact information
      #
      # @example initialization:
      #   Mobile::V0::UserSerializer.new(@current_user, options)
      def initialize(user, options = {})
        @user = user
        fetch_additional_resources
        resource = UserStruct.new(user.id, profile, authorized_services, health)
        super(resource, options)
      end

      private

      def filter_keys(value, keys)
        value&.to_h&.slice(*keys)
      end

      def profile
        {
          first_name: user.first_name,
          middle_name: user.middle_name,
          last_name: user.last_name,
          contact_email: filter_keys(contact_info&.email, EMAIL_KEYS),
          signin_email: user.email,
          birth_date: user.birth_date.nil? ? nil : Date.parse(user.birth_date).iso8601,
          gender: user.gender,
          residential_address: filter_keys(contact_info&.residential_address, ADDRESS_KEYS),
          mailing_address: filter_keys(contact_info&.mailing_address, ADDRESS_KEYS),
          home_phone_number: filter_keys(contact_info&.home_phone, PHONE_KEYS),
          mobile_phone_number: filter_keys(contact_info&.mobile_phone, PHONE_KEYS),
          work_phone_number: filter_keys(contact_info&.work_phone, PHONE_KEYS),
          fax_number: filter_keys(contact_info&.fax_number, PHONE_KEYS),
          signin_service: user.identity.sign_in[:service_name].remove('oauth_')
        }
      end

      def authorized_services
        auth_services = SERVICE_DICTIONARY.filter { |_k, policies| authorized_for_service(policies) }.keys
        if auth_services.include?(:directDepositBenefits) && direct_deposit_update_access?
          auth_services.push(:directDepositBenefitsUpdate)
        end
        auth_services
      end

      def direct_deposit_update_access?
        user.authorize(:ppiu, :access_update?)
      rescue EVSS::PPIU::ServiceException => e
        Rails.logger.error('Error fetching user data from EVSS', user_uuid: user.uuid, details: e.messages)
        false
      end

      def health
        facility_ids = user.va_treatment_facility_ids
        {
          facilities: facility_ids.map.with_index { |id, index| facility(id, facility_names[index]) },
          is_cerner_patient: !user.cerner_id.nil?
        }
      end

      def authorized_for_service(policies)
        [*policies].all? { |policy| user.authorize(policy, :access?) }
      end

      def facility(facility_id, facility_name)
        cerner_facility_ids = user.cerner_facility_ids || []
        {
          facility_id: facility_id,
          is_cerner: cerner_facility_ids.include?(facility_id),
          facility_name: facility_name.nil? ? '' : facility_name
        }
      end

      def fetch_additional_resources
        @facility_names, @contact_info = Parallel.map([fetch_locations, fetch_contact_info], in_threads: 2, &:call)
      end

      # fetches MPI, either from external source or cache, then makes an external call for facility data
      def fetch_locations
        lambda {
          Mobile::FacilitiesHelper.get_facility_names(user.va_treatment_facility_ids)
        }
      end

      # this may make an external call if the data is not cached
      def fetch_contact_info
        lambda {
          user.vet360_contact_info
        }
      end
    end

    UserStruct = Struct.new(:id, :profile, :authorized_services, :health)
  end
end
