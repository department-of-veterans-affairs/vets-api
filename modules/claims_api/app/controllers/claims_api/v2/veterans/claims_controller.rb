# frozen_string_literal: true

require 'claims_api/bgs_claim_status_mapper'
require 'claims_api/v2/mock_documents_service'
require 'claims_api/v2/claims/claim_validator'
require 'claims_api/v2/claims/claim_mapper'

module ClaimsApi
  module V2
    module Veterans
      class ClaimsController < ClaimsApi::V2::ApplicationController
        before_action :set_bgs_claims, :set_lighthouse_claims, :render_if_no_claims, only: %i[index]
        before_action :set_lighthouse_claim, :set_bgs_claim, :raise_if_no_claims_for_id!, :validate_id_with_icn!,
                      only: %i[show]

        def index
          render json: claims_map
        end

        def show
          render json: claim_map
        end

        private

        def set_bgs_claims
          @bgs_claims = find_bgs_claims!
        end

        def set_lighthouse_claims
          @lighthouse_claims = ClaimsApi::AutoEstablishedClaim.where(veteran_icn: target_veteran.mpi.icn)
        end

        # Does not work exactly as it appears
        def render_if_no_claims
          render json: [] && return unless @bgs_claims || @lighthouse_claims
        end

        def claims_map
          mapped_claims = ClaimMapper.new(
            bgs_claims: @bgs_claims,
            lighthouse_claims: @lighthouse_claims,
            request:,
            token:,
            current_user:,
            target_veteran:
          ).map_claims
          blueprint_options = { base_url: request.base_url, veteran_id: params[:veteranId], view: :index, root: :data }

          ClaimsApi::V2::Blueprints::ClaimBlueprint.render(mapped_claims, blueprint_options)
        end

        def claim_map
          mapped_claim = ClaimMapper.new(
            bgs_claim: @bgs_claim,
            lighthouse_claim: @lighthouse_claim,
            request:,
            token:,
            current_user:,
            target_veteran:,
            params:
          ).map_claim
          blueprint_options = { base_url: request.base_url, veteran_id: params[:veteranId], view: :show, root: :data }

          ClaimsApi::V2::Blueprints::ClaimBlueprint.render(mapped_claim, blueprint_options)
        end

        def set_lighthouse_claim
          @lighthouse_claim = find_lighthouse_claim!(claim_id: params[:id])
        end

        def set_bgs_claim
          benefit_claim_id = @lighthouse_claim.present? ? @lighthouse_claim.evss_id : params[:id]
          @bgs_claim = find_bgs_claim!(claim_id: benefit_claim_id)
        end

        def raise_if_no_claims_for_id!
          if @lighthouse_claim.blank? && @bgs_claim.blank?
            claims_v2_logging('claims_show', level: :warn, message: 'Claim not found.')
            raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claim not found')
          end
        end

        def validate_id_with_icn!
          ClaimValidator.new(@bgs_claim, @lighthouse_claim, params[:veteranId], target_veteran).validate!
        end

        def find_lighthouse_claim!(claim_id:)
          lighthouse_claim = ClaimsApi::AutoEstablishedClaim.get_by_id_and_icn(claim_id, target_veteran.mpi.icn)

          if looking_for_lighthouse_claim?(claim_id:) && lighthouse_claim.blank?
            raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claim not found')
          end

          lighthouse_claim
        end

        def find_bgs_claim!(claim_id:)
          return if claim_id.blank?

          local_bgs_service.find_benefit_claim_details_by_benefit_claim_id(
            claim_id
          )
        end

        def find_bgs_claims!
          local_bgs_service.find_benefit_claims_status_by_ptcpnt_id(
            target_veteran.participant_id
          )
        end

        def looking_for_lighthouse_claim?(claim_id:)
          claim_id.to_s.include?('-')
        end
      end
    end
  end
end
