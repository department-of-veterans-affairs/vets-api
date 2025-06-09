# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require 'simple_forms_api_submission/metadata_validator'

module AccreditedRepresentativePortal
  module V0
    class RepresentativeFormUploadController < ApplicationController
      include AccreditedRepresentativePortal::V0::RepresentativeFormUploadConcern

      def submit
        authorize(claimant_representative, policy_class: RepresentativeFormUploadPolicy)
        Datadog::Tracing.active_trace&.set_tag('form_id', form_data[:formNumber])
        render json: SavedClaimSerializer.new(saved_claim).as_json.to_h.deep_transform_keys { |key| key.camelize(:lower) }
      end

      def upload_scanned_form
        authorize(nil, policy_class: RepresentativeFormUploadPolicy)
        attachment = PersistentAttachments::VAForm.new
        attachment.form_id = params['form_id']
        attachment.file = params['file']
        raise Common::Exceptions::ValidationErrors, attachment unless attachment.valid?

        attachment.save
        serialized = PersistentAttachmentVAFormSerializer.new(attachment).as_json.deep_transform_keys do |key|
          key.camelize(:lower)
        end
        render json: serialized
      end

      private

      def claimant_id
        @claimant_id ||= get_icn
      end

      def saved_claim
        AccreditedRepresentativePortal::SavedClaimService::Create.perform(
          type: AccreditedRepresentativePortal::SavedClaim::BenefitsIntake::DependencyClaim,
          attachment_guids: [params[:confirmationCode]], # TODO: multi form upload
          metadata: get_metadata,
          claimant_representative:
        )
      end

      def claimant_representative
        @claimant_representative ||= ClaimantRepresentative.find do |finder|
          finder.for_claimant(
            icn: claimant_id,
          )

          finder.for_representative(
            icn: current_user.icn,
            email: current_user.email
          )
        end
      end

      def lighthouse_service
        @lighthouse_service ||= BenefitsIntake::Service.new
      end

      def get_icn
        ##
        # TODO: Remove. This is for temporary debugging into different behavior
        # observed between localhost and staging.
        #
        if Settings.vsp_environment != 'production'
          log_value = { ssn:, first_name:, last_name:, birth_date: }
          log_value = log_value.deep_transform_values do |v|
            { class: v.class, size: v.try(:size) }
          end

          Rails.logger.error(
            'arp_olive_branch_debugging',
            log_value
          )
        end

        mpi = MPI::Service.new.find_profile_by_attributes(ssn:, first_name:, last_name:, birth_date:)

        if mpi.profile&.icn
          mpi.profile.icn
        else
          raise Common::Exceptions::RecordNotFound, 'Could not lookup claimant with given information.'
        end
      end
    end
  end
end
