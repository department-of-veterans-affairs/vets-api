# frozen_string_literal: true

require 'accredited_representative_portal/monitor'

module AccreditedRepresentativePortal
  module V0
    class IntentToFileController < ApplicationController
      INTENT_TO_FILE_TYPES = %w[compensation pension survivor].freeze

      MOCK_ITF_NOT_FOUND = {
        'errors' => [{
          'title' => 'Resource not found',
          'detail' => "No active 'C' intent to file found.",
          'code' => '404',
          'status' => '404'
        }]
      }.freeze

      ATTEMPT_METRIC = 'ar.itf.submit.attempt'
      SUCCESS_METRIC = 'ar.itf.submit.success'
      ERROR_METRIC   = 'ar.itf.submit.error'

      before_action :validate_file_type, only: %i[show create]
      before_action { authorize icn, policy_class: IntentToFilePolicy }

      def show
        parsed_response = if Flipper.enabled?(:accredited_representative_portal_skip_itf_check)
                            MOCK_ITF_NOT_FOUND
                          else
                            intent_to_file_check_service.get_intent_to_file(params[:benefitType])
                          end

        if parsed_response['errors']&.first.try(:[], 'title') == 'Resource not found'
          raise Common::Exceptions::RecordNotFound, parsed_response['errors']&.first&.[]('detail')
        else
          render json: parsed_response, status: :ok
        end
      end

      # rubocop:disable Metrics/MethodLength
      def create
        monitoring = ar_monitoring
        monitoring.track_count(ATTEMPT_METRIC, tags: default_tags)

        parsed_response = submit_service.create_intent_to_file(params[:benefitType], params[:claimantSsn])
        Rails.logger.info('ARP ITF: Created intent to file in Benefits Claims')

        if parsed_response['errors'].present?
          normalized_reason = normalize_error(parsed_response['errors']&.first)
          monitoring.track_count(ERROR_METRIC, tags: default_tags + ["reason:#{normalized_reason}"])
          Rails.logger.warn("ARP ITF: Error response - error_count: #{parsed_response['errors']&.count}")
          raise ActionController::BadRequest.new(error: parsed_response['errors']&.first&.[]('detail'))
        else
          SavedClaim::BenefitsClaims::IntentToFile.transaction do
            icn_temporary_identifier = IcnTemporaryIdentifier.save_icn(icn)
            Rails.logger.info('ARP ITF: IcnTemporaryIdentifier created')
            claimant_type = params[:benefitType] == 'survivor' ? :dependent : :veteran
            saved_claim = SavedClaim::BenefitsClaims::IntentToFile.create!(form: form.to_json)
            Rails.logger.info('ARP ITF: SavedClaim::BenefitsClaims::IntentToFile created')

            SavedClaimClaimantRepresentative.create!(
              saved_claim:,
              claimant_type:,
              claimant_id: icn_temporary_identifier.id,
              power_of_attorney_holder_type: power_of_attorney_holder.type,
              power_of_attorney_holder_poa_code: power_of_attorney_holder.poa_code,
              accredited_individual_registration_number:
                claimant_representative.accredited_individual_registration_number
            )
          end

          Rails.logger.info('ARP ITF: SavedClaimClaimantRepresentative created')
          monitoring.track_count(SUCCESS_METRIC, tags: default_tags)
          render json: parsed_response, status: :created
        end
      rescue ArgumentError => e
        monitoring&.track_count(ERROR_METRIC, tags: default_tags + ['reason:argument_error'])
        Rails.logger.warn('ARP ITF: ArgumentError during ITF creation')
        render json: { error: e.message }, status: :bad_request
      rescue => e
        normalized_reason = e.class.name.downcase.split('::').last
        monitoring&.track_count(ERROR_METRIC, tags: default_tags + ["reason:#{normalized_reason}"])
        Rails.logger.error("ARP ITF: ERROR - #{e.class}: #{e.message.truncate(100)}")
        raise
      end
      # rubocop:enable Metrics/MethodLength

      private

      def veteran_form
        {
          benefitType: params[:benefitType],
          veteran: {
            ssn: params[:veteranSsn],
            dateOfBirth: params[:veteranDateOfBirth],
            vaFileNumber: params[:vaFileNumber],
            name: {
              first: params[:veteranFullName][:first],
              last: params[:veteranFullName][:last]
            }
          }
        }
      end

      def claimant_form
        {
          dependent: {
            ssn: params[:claimantSsn],
            dateOfBirth: params[:claimantDateOfBirth],
            name: {
              first: params[:claimantFullName][:first],
              last: params[:claimantFullName][:last]
            }
          }
        }
      end

      def form
        if params[:benefitType] == 'survivor'
          veteran_form.merge(claimant_form)
        else
          veteran_form.merge(dependent: nil)
        end
      end

      def intent_to_file_check_service
        @intent_to_file_check_service ||= BenefitsClaims::Service.new(icn)
      end

      def submit_service
        @submit_service ||= BenefitsClaims::Service.new(veteran_icn)
      end

      def icn
        params[:benefitType] == 'survivor' ? claimant_icn : veteran_icn
      end

      def veteran_icn
        @veteran_icn ||= ClaimantLookupService.get_icn(
          params[:veteranFirstName] || params[:veteranFullName][:first],
          params[:veteranLastName] || params[:veteranFullName][:last],
          params[:veteranSsn],
          params[:veteranDateOfBirth]
        )
      rescue Common::Exceptions::RecordNotFound => e
        raise Common::Exceptions::BadRequest.new(detail: e.message)
      end

      def claimant_icn
        @claimant_icn ||= ClaimantLookupService.get_icn(
          params[:claimantFirstName] || params[:claimantFullName][:first],
          params[:claimantLastName] || params[:claimantFullName][:last],
          params[:claimantSsn],
          params[:claimantDateOfBirth]
        )
      rescue Common::Exceptions::RecordNotFound => e
        raise Common::Exceptions::BadRequest.new(detail: e.message)
      end

      def validate_file_type
        unless INTENT_TO_FILE_TYPES.include? params[:benefitType]
          raise ActionController::BadRequest, <<~MSG.squish
            Invalid type parameter.
            Must be one of (#{INTENT_TO_FILE_TYPES.join(', ')})
          MSG
        end
      end

      def claimant_representative
        @claimant_representative ||= ClaimantRepresentative.find(
          claimant_icn: icn,
          power_of_attorney_holder_memberships:
            @current_user.power_of_attorney_holder_memberships
        )
      end

      def power_of_attorney_holder
        claimant_representative.power_of_attorney_holder
      end

      def ar_monitoring
        AccreditedRepresentativePortal::Monitoring.new(
          AccreditedRepresentativePortal::Monitoring::NAME,
          default_tags:
        )
      end

      # ---- Defensive Datadog tags only ----
      def default_tags
        org_tag = 'org_resolve:failed'
        poa_code = organization
        org_tag = "org:#{poa_code}" if poa_code.present?

        [
          org_tag,
          "benefit_type:#{params[:benefitType]}"
        ]
      end

      # nil-safe retrieval for monitoring only
      def organization
        power_of_attorney_holder&.poa_code
      rescue
        nil
      end

      def normalize_error(error)
        return 'unknown_error' if error.blank? || error['title'].blank?

        error['title'].parameterize(separator: '_')
      end
    end
  end
end
