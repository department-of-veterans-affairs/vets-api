# frozen_string_literal: true

module ClaimsApi
  module V2
    module Veterans
      class ClaimsController < ClaimsApi::V2::ApplicationController
        before_action :verify_access!

        def index
          bgs_claims = bgs_service.ebenefits_benefit_claims_status.find_benefit_claims_status_by_ptcpnt_id(
            participant_id: target_veteran.participant_id
          )
          lighthouse_claims = ClaimsApi::AutoEstablishedClaim.where(veteran_icn: target_veteran.mpi.icn)

          render json: [] && return unless bgs_claims || lighthouse_claims
          mapped_claims = map_claims(bgs_claims: bgs_claims, lighthouse_claims: lighthouse_claims)

          blueprint_options = { base_url: request.base_url, veteran_id: params[:veteranId], view: :list }
          render json: ClaimsApi::V2::Blueprints::ClaimBlueprint.render(mapped_claims, blueprint_options)
        end

        def show
          lighthouse_claim = find_lighthouse_claim!(claim_id: params[:id])
          benefit_claim_id = lighthouse_claim.present? ? lighthouse_claim.evss_id : params[:id]
          bgs_claim = find_bgs_claim!(claim_id: benefit_claim_id)

          if lighthouse_claim.blank? && bgs_claim.blank?
            raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claim not found')
          end

          bgs_claim = massage_bgs_claim(bgs_claim: bgs_claim) if bgs_claim.present?
          claim = BGSToLighthouseClaimsMapperService.process(bgs_claim: bgs_claim, lighthouse_claim: lighthouse_claim)

          blueprint_options = { base_url: request.base_url, veteran_id: params[:veteranId] }
          render json: ClaimsApi::V2::Blueprints::ClaimBlueprint.render(claim, blueprint_options)
        end

        private

        def bgs_service
          BGS::Services.new(external_uid: target_veteran.participant_id,
                            external_key: target_veteran.participant_id)
        end

        def map_claims(bgs_claims:, lighthouse_claims:)
          mapped_claims = bgs_claims[:benefit_claims_dto][:benefit_claim].map do |bgs_claim|
            matching_claim = find_bgs_claim_in_lighthouse_collection(
              lighthouse_collection: lighthouse_claims,
              bgs_claim: bgs_claim
            )
            if matching_claim
              lighthouse_claims.delete(matching_claim)
              BGSToLighthouseClaimsMapperService.process(bgs_claim: bgs_claim, lighthouse_claim: matching_claim)
            else
              BGSToLighthouseClaimsMapperService.process(bgs_claim: bgs_claim)
            end
          end

          lighthouse_claims.each do |remaining_claim|
            # if claim wasn't matched earlier, then this claim is in a weird state where
            #  it's 'established' in Lighthouse, but unknown to BGS.
            #  shouldn't really ever happen, but if it does, skip it.
            next if remaining_claim.status.casecmp?('established')

            mapped_claims << BGSToLighthouseClaimsMapperService.process(lighthouse_claim: remaining_claim)
          end

          mapped_claims
        end

        def find_bgs_claim_in_lighthouse_collection(lighthouse_collection:, bgs_claim:)
          # EVSS and BGS use the same ID to refer to a claim, hence the following
          # search condition to see if we've stored the same claim in vets-api
          lighthouse_collection.find { |lighthouse_claim| lighthouse_claim.evss_id == bgs_claim[:benefit_claim_id] }
        end

        def find_lighthouse_claim!(claim_id:)
          lighthouse_claim = ClaimsApi::AutoEstablishedClaim.get_by_id_or_evss_id(claim_id)

          if looking_for_lighthouse_claim?(claim_id: claim_id) && lighthouse_claim.blank?
            raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claim not found')
          end

          lighthouse_claim
        end

        def find_bgs_claim!(claim_id:)
          bgs_service.ebenefits_benefit_claims_status.find_benefit_claim_details_by_benefit_claim_id(
            benefit_claim_id: claim_id
          )
        rescue Savon::SOAPFault => e
          # the ebenefits service raises an exception if a claim is not found,
          # so catch the exception here and return a 404 instead
          if e.message.include?("No BnftClaim found for #{claim_id}")
            raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claim not found')
          end

          raise
        end

        def looking_for_lighthouse_claim?(claim_id:)
          claim_id.to_s.include?('-')
        end

        # the 'ebenefits' services used in the 'index' and 'show' actions return differing data structures
        #  massage the 'show' data structure to be in a state that the BGSToLighthouseClaimsMapperService can use
        def massage_bgs_claim(bgs_claim:)
          claim_details = bgs_claim[:benefit_claim_details_dto]
          {
            benefit_claim_id: claim_details[:benefit_claim_id],
            attention_needed: claim_details[:attention_needed],
            claim_dt: claim_details[:claim_dt],
            claim_status_type: claim_details[:claim_status_type],
            contentions: claim_details[:contentions]&.split(','),
            va_representative: claim_details[:poa]&.titleize,
            phase_type: claim_details[:bnft_claim_lc_status][:phase_type],
            end_product_code: claim_details[:end_prdct_type_cd],
            filed5103_waiver_ind: claim_details[:filed5103_waiver_ind],
            development_letter_sent: claim_details[:development_letter_sent],
            decision_notification_sent: claim_details[:decision_notification_sent]
          }
        end
      end
    end
  end
end
