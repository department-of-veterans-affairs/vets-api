# frozen_string_literal: true

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

      before_action :check_feature_toggle
      before_action :validate_file_type, only: %i[show create]
      before_action { authorize icn, policy_class: IntentToFilePolicy }

      def show
        parsed_response = if Flipper.enabled?(:accredited_representative_portal_skip_itf_check)
                            MOCK_ITF_NOT_FOUND
                          else
                            service.get_intent_to_file(params[:benefitType])
                          end

        if parsed_response['errors']&.first.try(:[], 'title') == 'Resource not found'
          raise Common::Exceptions::RecordNotFound, parsed_response['errors']&.first&.[]('detail')
        else
          render json: parsed_response, status: :ok
        end
      end

      # rubocop:disable Metrics/MethodLength
      # Temporary for additional logging - errors not getting caught by Datadog
      def create
        parsed_response = service.create_intent_to_file(params[:benefitType], params[:claimantSsn])
        Rails.logger.info('ARP ITF: Created intent to file in Benefits Claims')

        if parsed_response['errors'].present?
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
              saved_claim:, claimant_type:, claimant_id: icn_temporary_identifier.id,
              power_of_attorney_holder_type: power_of_attorney_holder.type,
              power_of_attorney_holder_poa_code: power_of_attorney_holder.poa_code,
              accredited_individual_registration_number:
                claimant_representative.accredited_individual_registration_number
            )
          end
          Rails.logger.info('ARP ITF: SavedClaimClaimantRepresentative created')
          render json: parsed_response, status: :created
        end
      rescue ArgumentError => e
        Rails.logger.warn('ARP ITF: ArgumentError during ITF creation')
        render json: { error: e.message }, status: :bad_request
      rescue => e
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

      def check_feature_toggle
        unless Flipper.enabled?(:accredited_representative_portal_intent_to_file, @current_user)
          message = 'The accredited_representative_portal_intent_to_file feature flag is disabled ' \
                    "for the user with uuid: #{@current_user.uuid}"

          raise Common::Exceptions::Forbidden, detail: message
        end
      end

      def service
        @service ||= BenefitsClaims::Service.new(icn)
      end

      def icn
        @icn ||= ClaimantLookupService.get_icn(
          params[:veteranFirstName] || params[:veteranFullName][:first],
          params[:veteranLastName] || params[:veteranFullName][:last],
          params[:veteranSsn],
          params[:veteranDateOfBirth]
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
    end
  end
end
