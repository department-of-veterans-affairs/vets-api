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

          output = generate_show_output(bgs_claim: bgs_claim, lighthouse_claim: lighthouse_claim)
          blueprint_options = { base_url: request.base_url, veteran_id: params[:veteranId] }
          render json: ClaimsApi::V2::Blueprints::ClaimBlueprint.render(output, blueprint_options)
        end

        private

        def bgs_service
          BGS::Services.new(external_uid: target_veteran.participant_id,
                            external_key: target_veteran.participant_id)
        end

        def generate_show_output(bgs_claim:, lighthouse_claim:)
          if lighthouse_claim.present? && bgs_claim.present?
            bgs_details = bgs_claim[:benefit_claim_details_dto]
            build_claim_structure(
              data: bgs_details,
              lighthouse_id: lighthouse_claim.id,
              upstream_id: bgs_details[:benefit_claim_id]
            )
          elsif lighthouse_claim.present? && bgs_claim.blank?
            {
              lighthouse_id: lighthouse_claim.id,
              type: lighthouse_claim.claim_type,
              status: lighthouse_claim.status.capitalize
            }
          else
            bgs_details = bgs_claim[:benefit_claim_details_dto]
            build_claim_structure(data: bgs_details, lighthouse_id: nil, upstream_id: bgs_details[:benefit_claim_id])
          end
        end

        def map_claims(bgs_claims:, lighthouse_claims:) # rubocop:disable Metrics/MethodLength
          mapped_claims = bgs_claims[:benefit_claims_dto][:benefit_claim].map do |bgs_claim|
            matching_claim = find_bgs_claim_in_lighthouse_collection(
              lighthouse_collection: lighthouse_claims,
              bgs_claim: bgs_claim
            )

            if matching_claim
              lighthouse_claims.delete(matching_claim)
              build_claim_structure(
                data: bgs_claim,
                lighthouse_id: matching_claim.id,
                upstream_id: bgs_claim[:benefit_claim_id]
              )
            else
              build_claim_structure(data: bgs_claim, lighthouse_id: nil, upstream_id: bgs_claim[:benefit_claim_id])
            end
          end

          lighthouse_claims.each do |remaining_claim|
            # if claim wasn't matched earlier, then this claim is in a weird state where
            #  it's 'established' in Lighthouse, but unknown to BGS.
            #  shouldn't really ever happen, but if it does, skip it.
            next if remaining_claim.status.casecmp?('established')

            mapped_claims << {
              lighthouse_id: remaining_claim.id,
              type: remaining_claim.claim_type,
              status: remaining_claim.status.capitalize
            }
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
          return if claim_id.blank?

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

        def build_claim_structure(data:, lighthouse_id:, upstream_id:) # rubocop:disable Metrics/MethodLength
          {
            benefit_claim_type_code: data[:bnft_claim_type_cd],
            claim_id: upstream_id,
            claim_type: data[:claim_status_type],
            contention_list: data[:contentions]&.split(','),
            claim_date: data[:claim_dt].present? ? data[:claim_dt].strftime('%D') : nil,
            decision_letter_sent: map_yes_no_to_boolean(
              'decision_notification_sent',
              data[:decision_notification_sent]
            ),
            development_letter_sent: map_yes_no_to_boolean('development_letter_sent', data[:development_letter_sent]),
            documents_needed: map_yes_no_to_boolean('attention_needed', data[:attention_needed]),
            end_product_code: data[:end_prdct_type_cd],
            jurisdiction: data[:regional_office_jrsdctn],
            lighthouse_id: lighthouse_id,
            maxEstClaimDate: data[:max_est_claim_complete_dt],
            minEstClaimDate: data[:min_est_claim_complete_dt],
            status: detect_status(data),
            submitter_application_code: data[:submtr_applcn_type_cd],
            submitter_role_code: data[:submtr_role_type_cd],
            '5103_waiver_submitted'.to_sym => map_yes_no_to_boolean('filed5103_waiver_ind',
                                                                    data[:filed5103_waiver_ind]),
            tempJurisdiction: data[:temp_regional_office_jrsdctn]
          }
        end

        def detect_status(data)
          return data[:phase_type] if data.key?(:phase_type)

          cast_claim_lc_status(data[:bnft_claim_lc_status])
        end

        # The status can either be an object or array
        # This picks the most recent status from the array
        def cast_claim_lc_status(status)
          return if status.blank?

          stat = [status].flatten.max_by do |t|
            t[:phase_chngd_dt]
          end
          stat[:phase_type]
        end

        def map_yes_no_to_boolean(key, value)
          # Requested decision appears to be included in the BGS payload
          # only when it is yes. Assume an ommission is akin to no, i.e., false
          return false if value.blank?

          case value.downcase
          when 'yes', 'y' then true
          when 'no', 'n' then false
          else
            Rails.logger.error "Expected key '#{key}' to be Yes/No. Got '#{s}'."
            nil
          end
        end
      end
    end
  end
end
