# frozen_string_literal: true

module Mobile
  module V0
    class UserAccessibleServices
      def initialize(user)
        @user = user
      end

      def authorized
        service_auth_map.select { |_, v| v == true }.keys.sort
      end

      # forming this requires evaluating all auth rules. Currently, they are only used together. if we ever need
      # available services without authorized services we should decouple them.
      def available
        service_auth_map.keys.sort
      end

      # rubocop:disable Metrics/MethodLength
      def service_auth_map
        @service_auth_map ||= {
          appeals: access?(appeals: :access?),
          appointments: access?(vaos: :access?) && @user.icn.present?,
          claims: flagged_access?(:mobile_lighthouse_claims, { lighthouse: :access? }, { evss: :access? }),
          decisionLetters: access?(bgs: :access?),
          directDepositBenefits: flagged_access?(:mobile_lighthouse_direct_deposit, { lighthouse: :mobile_access? },
                                                 { evss: :access?, ppiu: :access? }),
          directDepositBenefitsUpdate: direct_deposit_update_access?,
          disabilityRating: flagged_access?(:mobile_lighthouse_disability_ratings, { lighthouse: :access? },
                                            { evss: :access? }),
          genderIdentity: access?(demographics: :access_update?) && access?(mpi: :queryable?),
          lettersAndDocuments: flagged_access?(:mobile_lighthouse_letters, { lighthouse: :access? },
                                               { evss: :access? }),
          militaryServiceHistory: access?(vet360: :military_access?),
          paymentHistory: access?(bgs: :access?),
          preferredName: access?(demographics: :access_update?) && access?(mpi: :queryable?),
          prescriptions: access?(mhv_prescriptions: :access?),
          scheduleAppointments: access?(schedule_appointment: :access?),
          secureMessaging: flagged_access?(:mobile_sm_session_policy, { mhv_messaging: :mobile_access? },
                                           { legacy_mhv_messaging: :access? }),
          userProfileUpdate: access?(vet360: :access?)
        }
      end
      # rubocop:enable Metrics/MethodLength

      private

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

      # ppiu access_update? makes an upstream request. default to false when call fails
      def direct_deposit_update_access?
        flagged_access?(:mobile_lighthouse_direct_deposit, { lighthouse: :mobile_access? },
                        { evss: :access?, ppiu: %i[access? access_update?] })
      rescue
        false
      end
    end
  end
end
