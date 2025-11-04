# frozen_string_literal: true

module Mobile
  module V0
    class UserAccessibleServices
      def initialize(user, request = nil)
        @user = user
        @request = request
      end

      def authorized
        service_auth_map.select { |_, v| v == true }.keys.sort
      end

      # forming this requires evaluating all auth rules. Currently, they are only used together. if we ever need
      # available services without authorized services we should decouple them.
      def available
        service_auth_map.keys.sort
      end

      def service_auth_map # rubocop:disable Metrics/MethodLength
        @service_auth_map ||= {
          allergiesOracleHealthEnabled: Flipper.enabled?(:mhv_accelerated_delivery_allergies_enabled, @user),
          appeals: access?(appeals: :access?),
          appointments: access?(vaos: :access?) && @user.icn.present? && access?(vaos: :facilities_access?),
          claims: access?(lighthouse: :access?),
          decisionLetters: access?(bgs: :access?),
          directDepositBenefits: access?(lighthouse: :mobile_access?),
          directDepositBenefitsUpdate: access?(lighthouse: :mobile_access?),
          disabilityRating: access?(lighthouse: :access?),
          genderIdentity: access?(demographics: :access_update?) && access?(mpi: :queryable?),
          lettersAndDocuments: access?(lighthouse: :access?),
          militaryServiceHistory: access?(vet360: :military_access?),
          medicationsOracleHealthEnabled: medications_oracle_health_enabled?,
          paymentHistory: access?(bgs: :access?),
          preferredName: access?(demographics: :access_update?) && access?(mpi: :queryable?),
          prescriptions: access?(mhv_prescriptions: :access?),
          scheduleAppointments: access?(schedule_appointment: :access?),
          secureMessaging: access?(mhv_messaging: :mobile_access?),
          secureMessagingOracleHealthEnabled: Flipper.enabled?(:mhv_secure_messaging_cerner_pilot, @user),
          userProfileUpdate: access?(va_profile: :access_to_v2?)
        }
      end # rubocop:enable Metrics/MethodLength

      private

      def medications_oracle_health_enabled?
        return false unless Flipper.enabled?(:mhv_medications_cerner_pilot, @user)
        return true if @request.nil? # Allow tests without request context
        return false if app_version_header.nil? # Default to disabled if no version header

        # Check if version meets minimum requirement
        begin
          version = Gem::Version.new(app_version_header)
          min_version = Gem::Version.new(Settings.va_mobile.medications_oracle_health_min_version)
          version >= min_version
        rescue ArgumentError
          # Treat malformed version as not meeting requirement
          false
        end
      end

      def app_version_header
        @request&.headers&.[]('App-Version')
      end

      def flagged_access?(flag_name, flag_on_policy, flag_off_policy)
        if Flipper.enabled?(flag_name, @user)
          access?(flag_on_policy)
        else
          access?(flag_off_policy)
        end
      end

      def access?(policies)
        policies.all? do |policy_name, policy_rule|
          if policy_rule.is_a? Array
            policy_rule.all? { |rule| access?({ policy_name => rule }) }
          else
            @user.authorize(policy_name, policy_rule)
          end
        end
      end
    end
  end
end
