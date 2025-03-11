# frozen_string_literal: true

require 'claims_api/bgs_claim_status_mapper'

module ClaimsApi
  module V2
    module Veterans
      class ClaimsController < ClaimsApi::V2::ApplicationController
        include ClaimsApi::V2::ClaimsRequests::TrackedItems
        include ClaimsApi::V2::ClaimsRequests::SupportingDocuments
        include ClaimsApi::V2::ClaimsRequests::TrackedItemsAssistance
        include ClaimsApi::V2::ClaimsRequests::ClaimValidation

        def index
          bgs_claims = find_bgs_claims!

          lighthouse_claims = ClaimsApi::AutoEstablishedClaim.where(veteran_icn: target_veteran.mpi.icn)

          return render json: [] if bgs_claims.blank? && lighthouse_claims.blank?

          mapped_claims = map_claims(bgs_claims:, lighthouse_claims:)
          blueprint_options = { base_url: request.base_url, veteran_id: params[:veteranId], view: :index, root: :data }
          render json: ClaimsApi::V2::Blueprints::ClaimBlueprint.render(mapped_claims, blueprint_options)
        end

        def show
          lighthouse_claim = find_lighthouse_claim!(claim_id: params[:id])
          benefit_claim_id = lighthouse_claim.present? ? lighthouse_claim.evss_id : params[:id]
          bgs_claim = find_bgs_claim!(claim_id: benefit_claim_id)

          if lighthouse_claim.blank? && bgs_claim.blank?
            claims_v2_logging('claims_show', level: :warn, message: 'Claim not found.')
            raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claim not found')
          end

          validate_id_with_icn(bgs_claim, lighthouse_claim, params[:veteranId])

          output = generate_show_output(bgs_claim:, lighthouse_claim:)
          blueprint_options = { base_url: request.base_url, veteran_id: params[:veteranId], view: :show, root: :data }

          render json: ClaimsApi::V2::Blueprints::ClaimBlueprint.render(output, blueprint_options)
        end

        private

        def bgs_phase_status_mapper
          ClaimsApi::BGSClaimStatusMapper.new
        end

        def generate_show_output(bgs_claim:, lighthouse_claim:) # rubocop:disable Metrics/MethodLength
          if lighthouse_claim.present? && bgs_claim.present?
            bgs_details = bgs_claim[:benefit_claim_details_dto]
            structure = build_claim_structure(
              'show',
              data: bgs_details,
              lighthouse_id: lighthouse_claim.id,
              upstream_id: bgs_details[:benefit_claim_id]
            )
          elsif lighthouse_claim.present? && bgs_claim.blank?
            structure = {
              lighthouse_id: lighthouse_claim.id,
              type: lighthouse_claim.claim_type,
              status: bgs_phase_status_mapper.name(lighthouse_claim)
            }
          else
            bgs_details = bgs_claim[:benefit_claim_details_dto]
            structure = build_claim_structure('show',
                                              data: bgs_details,
                                              lighthouse_id: nil,
                                              upstream_id: bgs_details[:benefit_claim_id])
          end
          ssn = auth_headers['va_eauth_pnid']
          structure.merge!(errors: get_errors(lighthouse_claim))
          structure.merge!(supporting_documents: build_supporting_docs(bgs_claim, ssn))
          structure.merge!(tracked_items: map_bgs_tracked_items(bgs_claim))
        end

        def map_claims(bgs_claims:, lighthouse_claims:)
          @unmatched_lighthouse_claims = lighthouse_claims
          extracted_bgs_claims = [bgs_claims&.dig(:benefit_claims_dto, :benefit_claim)].flatten.compact
          mapped_claims = extracted_bgs_claims.map do |bgs_claim|
            map_and_remove_duplicates(bgs_claim, lighthouse_claims)
          end

          handle_remaining_lh_claims(mapped_claims, @unmatched_lighthouse_claims)

          mapped_claims
        end

        def map_and_remove_duplicates(bgs_claim, lighthouse_claims)
          matching_claim = find_bgs_claim_in_lighthouse_collection(lighthouse_collection: lighthouse_claims,
                                                                   bgs_claim:)

          # Remove duplicates from the return
          @unmatched_lighthouse_claims = @unmatched_lighthouse_claims.where.not(id: matching_claim.id) if matching_claim

          # We either want the ID or nil for the lighthouse_id
          build_claim_structure('index', data: bgs_claim, lighthouse_id: matching_claim&.id,
                                         upstream_id: bgs_claim[:benefit_claim_id])
        end

        def handle_remaining_lh_claims(mapped_claims, lighthouse_claims)
          lighthouse_claims.each do |remaining_claim|
            # if claim wasn't matched earlier, then this claim is in a weird state where
            # it's 'established' in Lighthouse, but unknown to BGS.
            # shouldn't really ever happen, but if it does, skip it.
            next if remaining_claim.status.casecmp?('established')

            mapped_claims << {
              lighthouse_id: remaining_claim.id,
              claim_type: remaining_claim.claim_type,
              status: bgs_phase_status_mapper.name(remaining_claim)
            }
          end
        end

        def find_bgs_claim_in_lighthouse_collection(lighthouse_collection:, bgs_claim:)
          # EVSS and BGS use the same ID to refer to a claim, hence the following
          # search condition to see if we've stored the same claim in vets-api
          lighthouse_collection.find do |lighthouse_claim|
            lighthouse_claim.evss_id.to_s == bgs_claim[:benefit_claim_id]
          end
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

          bgs_claim_status_service.find_benefit_claim_details_by_benefit_claim_id(
            claim_id
          )
        end

        def find_bgs_claims!
          bgs_claim_status_service.find_benefit_claims_status_by_ptcpnt_id(
            target_veteran.participant_id
          )
        end

        def looking_for_lighthouse_claim?(claim_id:)
          claim_id.to_s.include?('-')
        end

        def build_claim_structure(view, data:, lighthouse_id:, upstream_id:) # rubocop:disable Metrics/MethodLength
          {
            base_end_prdct_type_cd: data[:base_end_prdct_type_cd],
            claim_date: date_present(data[:claim_dt]),
            claim_id: upstream_id,
            claim_phase_dates: build_claim_phase_attributes(data, view),
            claim_type_code: data[:bnft_claim_type_cd],
            claim_type: data[:claim_status_type],
            close_date: data[:claim_complete_dt].present? ? format_bgs_date(data[:claim_complete_dt]) : nil,
            contentions: build_contentions(data),
            decision_letter_sent: map_yes_no_to_boolean('decision_notification_sent',
                                                        data[:decision_notification_sent]),
            development_letter_sent: map_yes_no_to_boolean('development_letter_sent', data[:development_letter_sent]),
            documents_needed: map_yes_no_to_boolean('attention_needed', data[:attention_needed]),
            end_product_code: data[:end_prdct_type_cd],
            evidence_waiver_submitted_5103: waiver_boolean(data[:filed5103_waiver_ind]),
            jurisdiction: data[:regional_office_jrsdctn],
            lighthouse_id:,
            max_est_claim_date: date_present(data[:max_est_claim_complete_dt]),
            min_est_claim_date: date_present(data[:min_est_claim_complete_dt]),
            status: detect_current_status(data),
            submitter_application_code: data[:submtr_applcn_type_cd],
            submitter_role_code: data[:submtr_role_type_cd],
            temp_jurisdiction: data[:temp_regional_office_jrsdctn]
          }
        end

        def build_contentions(data)
          contentions = data[:contentions]&.split(/(?<=\)),/)
          return [] if contentions.nil?

          [].tap do |a|
            contentions.map do |contention|
              a << { name: contention.strip }
            end
          end
        end

        def current_phase_back(data)
          lc_status_array = [data&.dig(:bnft_claim_lc_status)].flatten
          return false if lc_status_array.nil?

          return false if lc_status_array.first&.dig(:phase_type_change_ind).nil?

          indicator = latest_phase_type_change_indicator(data).chars
          return false if indicator == 'N'

          indicator.first.to_i > indicator.last.to_i
        end

        def latest_phase_type_change_indicator(data)
          [data&.dig(:bnft_claim_lc_status)].flatten.first&.dig(:phase_type_change_ind)
        end

        def latest_phase_type(data)
          if data&.dig(:benefit_claim_details_dto, :bnft_claim_lc_status).present?
            latest = [data&.dig(:benefit_claim_details_dto, :bnft_claim_lc_status)].flatten.first&.dig(:phase_type)
          elsif data&.dig(:bnft_claim_lc_status).present?
            latest = [data&.dig(:bnft_claim_lc_status)].flatten.first&.dig(:phase_type)
          end
          return bgs_phase_status_mapper.get_phase_type_from_dictionary(latest.downcase) unless latest.nil?

          indicator = latest_phase_type_change_indicator(data).chars
          bgs_phase_status_mapper.get_phase_type_from_dictionary(indicator.last.to_i)
        end

        def get_current_status_from_hash(data)
          if data&.dig('benefit_claim_details_dto', 'bnft_claim_lc_status').present?
            data[:benefit_claim_details_dto][:bnft_claim_lc_status].last do |lc|
              phase_number = get_completed_phase_number_from_phase_details(lc)
              bgs_phase_status_mapper.name(lc[:phase_type], phase_number || nil)
            end
          elsif data&.dig(:phase_type).present?
            bgs_phase_status_mapper.name(data[:phase_type])
          end
        end

        def get_completed_phase_number_from_phase_details(details)
          if details[:phase_type_change_ind].present?
            return if details[:phase_type_change_ind] == 'N'

            details[:phase_type_change_ind].chars.first
          end
        end

        def get_bgs_phase_completed_dates(data)
          if data&.dig(:benefit_claim_details_dto, :bnft_claim_lc_status).present?
            lc_status_array =
              [data&.dig(:benefit_claim_details_dto, :bnft_claim_lc_status)].flatten&.compact
          elsif data&.dig(:bnft_claim_lc_status).present?
            lc_status_array =
              [data&.dig(:bnft_claim_lc_status)].flatten&.compact
          end
          return {} if lc_status_array&.first&.nil?

          max_completed_phase = lc_status_array&.first&.[](:phase_type_change_ind)&.chars&.last
          return {} if max_completed_phase&.downcase.eql?('n') || max_completed_phase.nil?

          {}.tap do |phase_date|
            lc_status_array.reverse.map do |phase|
              completed_phase_number = phase[:phase_type_change_ind].chars.first
              if completed_phase_number < max_completed_phase
                phase_date["phase#{completed_phase_number}CompleteDate"] = date_present(phase[:phase_chngd_dt])
              end
            end
          end.sort.reverse.to_h
        end

        def extract_date(bgs_details)
          bgs_details.is_a?(Array) ? bgs_details.first[:phase_chngd_dt] : bgs_details[:phase_chngd_dt]
        end

        def format_bgs_phase_date(data)
          bgs_details = data&.dig(:bnft_claim_lc_status)
          return {} if bgs_details.nil?

          date = extract_date(bgs_details)

          date_present(date)
        end

        def format_bgs_phase_chng_dates(data)
          phase_change_date = if data[:phase_chngd_dt].present?
                                data[:phase_chngd_dt]
                              elsif data[:benefit_claim_details_dto].present?
                                data[:benefit_claim_details_dto][:phase_chngd_dt]
                              elsif data[:bnft_claim_lc_status].present?
                                format_bgs_phase_date(data)
                              else
                                format_bgs_phase_date(data[:benefit_claim_details_dto])
                              end

          date_present(phase_change_date)
        end

        def detect_current_status(data)
          if data[:bnft_claim_lc_status].nil? && data.exclude?(:claim_status) && data.exclude?(:phase_type)
            return 'NO_STATUS_PROVIDED'
          end

          phase_data = if data[:claim_status] == 'CAN'
                         data[:claim_status]
                       elsif data[:phase_type].present?
                         data[:phase_type]
                       else
                         data[:bnft_claim_lc_status]
                       end

          return bgs_phase_status_mapper.name(phase_data) if phase_data.is_a?(String)

          phase_data.is_a?(Array) ? cast_claim_lc_status(phase_data) : get_current_status_from_hash(phase_data)
        end

        def get_errors(lighthouse_claim)
          return [] if lighthouse_claim.blank? || lighthouse_claim.evss_response.blank?

          lighthouse_claim.evss_response.map do |error|
            {
              detail: "#{error['severity']} #{error['detail'] || error['text']}".squish,
              source: error['key'] ? error['key'].gsub('.', '/') : error['key']
            }
          end
        end

        # The status can either be an object or array
        # This picks the most recent status from the array
        def cast_claim_lc_status(phase_data)
          return if phase_data.blank?

          phase = [phase_data].flatten.max do |a, b|
            a[:phase_chngd_dt] <=> b[:phase_chngd_dt]
          end
          phase_number = get_completed_phase_number_from_phase_details(phase_data.last)
          bgs_phase_status_mapper.name(phase[:phase_type], phase_number || nil)
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

        def waiver_boolean(filed5103_waiver_ind)
          filed5103_waiver_ind.present? ? filed5103_waiver_ind.downcase == 'y' : false
        end

        def map_status(item_id, unique_status)
          if supporting_document?(item_id)
            'SUBMITTED_AWAITING_REVIEW'
          else
            unique_status
          end
        end

        def uploads_allowed?(status)
          %w[NEEDED_FROM_YOU NEEDED_FROM_OTHERS SUBMITTED_AWAITING_REVIEW INITIAL_REVIEW_COMPLETE].include? status
        end

        def accepted?(status)
          ['Preparation for Decision', 'Pending Decision Approval', 'Preparation for Notification',
           'Complete'].include? status
        end

        def overdue?(tracked_item, wwsnfy)
          if tracked_item[:suspns_dt].present? && tracked_item[:accept_dt].nil? && wwsnfy
            return tracked_item[:suspns_dt] < Time.zone.now
          end

          false
        end

        def supporting_document?(id)
          @supporting_documents.find { |doc| doc[:tracked_item_id] == id.to_i }.present?
        end

        def find_tracked_item(id)
          [@tracked_items].flatten.compact.find { |item| item[:dvlpmt_item_id] == id }
        end

        def build_claim_phase_attributes(bgs_claim, view)
          return {} if bgs_claim.nil?

          case view
          when 'show'
            {
              phase_change_date: format_bgs_phase_chng_dates(bgs_claim),
              current_phase_back: current_phase_back(bgs_claim),
              latest_phase_type: latest_phase_type(bgs_claim),
              previous_phases: get_bgs_phase_completed_dates(bgs_claim)
            }
          when 'index'
            {
              phase_change_date: format_bgs_phase_chng_dates(bgs_claim),
              phase_type: bgs_phase_status_mapper.get_phase_type_from_dictionary(bgs_claim[:phase_type].downcase)
            }
          end
        end
      end
    end
  end
end
