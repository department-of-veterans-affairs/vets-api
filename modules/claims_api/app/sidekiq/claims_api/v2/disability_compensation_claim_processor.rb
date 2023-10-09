# frozen_string_literal: true

require 'claims_api/claim_logger'

module ClaimsApi
  module V2
    class DisabilityCompensationClaimProcessor

      def process_claim(claim_id, target_veteran_id)
        byebug
        @claim = get_claim(claim_id)
        @target_veteran = build_target_veteran(target_veteran_id)

        log_job_progress('dis_comp_claim_processor', 
            @claim, 
            '526EZ Claim Processor started')

        ClaimsApi::V2::DisabilityCompensationPdfGenerator.perform_async(@claim.id)
        #log_job_progress('dis_comp_claim_processor', 
            # claim_id, 
            # '526EZ Claim Processor finished')
      end

      protected

      #
      # Veteran being acted on.
      #
      # @return [ClaimsApi::Veteran] Veteran to act on
      def target_veteran
        @target_veteran ||= if 1 == 1
                              build_target_veteran(veteran_id: params[:veteranId], loa: { current: 3, highest: 3 })
                            elsif @validated_token_data && !@current_user.icn.nil?
                              build_target_veteran(veteran_id: @current_user.icn, loa: { current: 3, highest: 3 })
                            elsif user_is_representative?
                              build_target_veteran(veteran_id: params[:veteranId], loa: @current_user.loa)
                            else
                              raise ::Common::Exceptions::Unauthorized
                            end
      end

      def build_target_veteran(veteran_id:, loa:) # rubocop:disable Metrics/MethodLength
        target_veteran ||= ClaimsApi::Veteran.new(
          mhv_icn: veteran_id,
          loa:
        )
        # populate missing veteran attributes with their mpi record
        found_record = target_veteran.mpi_record?(user_key: veteran_id)

        unless found_record
          log_message_to_sentry("Claims v2 Veteran record not found - Veteran ICN: #{veteran_id}",
                                :warning)
          raise ::Common::Exceptions::ResourceNotFound.new(detail:
            "Unable to locate Veteran's ID/ICN in Master Person Index (MPI). " \
            'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.')
        end

        mpi_profile = target_veteran&.mpi&.mvi_response&.profile || {}

        if mpi_profile[:participant_id].blank?
          log_message_to_sentry("Claims v2 Veteran PID not found - Veteran ICN: #{veteran_id}",
                                :warning)
          raise ::Common::Exceptions::UnprocessableEntity.new(detail:
            "Unable to locate Veteran's Participant ID in Master Person Index (MPI). " \
            'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.')
        end

        target_veteran[:first_name] = mpi_profile[:given_names]&.first
        if target_veteran[:first_name].nil?
          log_message_to_sentry("Claims v2 Veteran First Name not found - Veteran ICN: #{veteran_id}",
                                :warning)
          raise ::Common::Exceptions::UnprocessableEntity.new(detail: 'Missing first name')
        end

        target_veteran[:last_name] = mpi_profile[:family_name]
        target_veteran[:edipi] = mpi_profile[:edipi]
        target_veteran[:uuid] = mpi_profile[:ssn]
        target_veteran[:ssn] = mpi_profile[:ssn]
        target_veteran[:participant_id] = mpi_profile[:participant_id]
        target_veteran[:last_signed_in] = Time.now.utc
        target_veteran[:va_profile] = ClaimsApi::Veteran.build_profile(mpi_profile.birth_date)
        target_veteran
      end

      def get_claim(claim_id)
        ClaimsApi::AutoEstablishedClaim.find(claim_id)
      end

      def log_job_progress(tag, claim, detail)
        byebug
        ClaimsApi::Logger.log(tag, 
            claim_id: claim.id, 
            detail: detail)
      end
    end
  end
end