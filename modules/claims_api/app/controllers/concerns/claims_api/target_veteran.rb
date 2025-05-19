# frozen_string_literal: true

require 'claims_api/claim_logger'

module ClaimsApi
  module TargetVeteran
    extend ActiveSupport::Concern

    included do
      def target_veteran
        @target_veteran ||= if @is_valid_ccg_flow
                              build_target_veteran(veteran_id: params[:veteranId], loa: { current: 3, highest: 3 })
                            elsif @validated_token_payload && !@current_user.icn.nil?
                              build_target_veteran(veteran_id: @current_user.icn, loa: { current: 3, highest: 3 })
                            elsif user_is_representative?
                              build_target_veteran(veteran_id: params[:veteranId], loa: @current_user.loa)
                            else
                              raise ::Common::Exceptions::Unauthorized
                            end
      end

      def build_target_veteran(veteran_id:, loa:)
        target_veteran ||= ClaimsApi::Veteran.new(
          mhv_icn: veteran_id,
          loa:
        )
        unless target_veteran.mpi_record?(user_key: veteran_id)
          claims_logging('unable_to_locate_id_or_icn',
                         message: 'unable_to_locate_id_or_icn on request in target veteran.')

          raise ::Common::Exceptions::ResourceNotFound.new(
            detail: "Unable to locate Veteran's ID/ICN in Master Person Index (MPI). " \
                    'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.'
          )
        end
        populate_target_veteran(mpi_profile_from(target_veteran), target_veteran)
      end

      def mpi_profile_from(target_veteran) # rubocop:disable Metrics/MethodLength
        mpi_profile = target_veteran&.mpi&.mvi_response&.profile || {}
        if mpi_profile.participant_id.blank?
          if Flipper.enabled?(:lighthouse_claims_api_add_person_proxy)
            claims_logging('add_person_proxy',
                           message: 'calling add_person_proxy in target veteran (Flipper on).')
            add_person_proxy_response = target_veteran.recache_mpi_data.add_person_proxy
            unless add_person_proxy_response.ok?
              claims_logging('unable_to_locate_participant_id',
                             message: 'unable_to_locate_participant_id on request in target veteran (Flipper on).' \
                                      "Failed call to add_person_proxy returned: #{add_person_proxy_response&.error}")

              raise ::Common::Exceptions::UnprocessableEntity.new(
                detail: "Unable to locate Veteran's Participant ID in Master Person Index (MPI). " \
                        'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.'
              )
            end
          else
            claims_logging('unable_to_locate_participant_id',
                           message: 'unable_to_locate_participant_id on request in target veteran (Flipper off).')

            raise ::Common::Exceptions::UnprocessableEntity.new(
              detail: "Unable to locate Veteran's Participant ID in Master Person Index (MPI). " \
                      'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.'
            )
          end
        end
        mpi_profile
      end # rubocop:enable Metrics/MethodLength

      def user_is_target_veteran?
        return false if params[:veteranId].blank?
        return false if @current_user.icn.blank?
        return false if target_veteran&.mpi&.icn.blank?
        return false unless params[:veteranId] == target_veteran.mpi.icn

        @current_user.icn == target_veteran.mpi.icn
      end

      def user_represents_veteran?
        return false if @current_user.first_name.nil? || @current_user.last_name.nil?

        reps = ::Veteran::Service::Representative.all_for_user(
          first_name: @current_user.first_name,
          last_name: @current_user.last_name
        )

        return false if reps.blank?
        return false if reps.count > 1

        rep = reps.first
        veteran_poa_code = ::Veteran::User.new(target_veteran)&.power_of_attorney&.code

        return false if veteran_poa_code.blank?

        rep.poa_codes.include?(veteran_poa_code)
      end

      def user_is_representative?
        return if @is_valid_ccg_flow

        first_name = @current_user.first_name
        last_name =  @current_user.last_name
        ::Veteran::Service::Representative.find_by(first_name, last_name).present?
      end
    end

    private

    def populate_target_veteran(mpi_profile, target_veteran)
      target_veteran.first_name = mpi_profile.given_names&.first
      target_veteran.last_name = mpi_profile.family_name
      target_veteran.gender = mpi_profile.gender
      target_veteran.edipi = mpi_profile.edipi
      target_veteran.uuid = mpi_profile.ssn
      target_veteran.ssn = mpi_profile.ssn
      target_veteran.participant_id = mpi_profile.participant_id
      target_veteran.last_signed_in = Time.now.utc
      target_veteran.va_profile = ClaimsApi::Veteran.build_profile(mpi_profile.birth_date)
      target_veteran
    end

    def claims_logging(tag = 'traceability', level: :info, message: nil)
      ClaimsApi::Logger.log(tag,
                            message:,
                            level:)
    end
  end
end
