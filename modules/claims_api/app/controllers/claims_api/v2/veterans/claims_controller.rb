# frozen_string_literal: true

require 'claims_api/bgs_claim_status_mapper'
require 'claims_api/v2/mock_documents_service'

module ClaimsApi
  module V2
    module Veterans
      class ClaimsController < ClaimsApi::V2::ApplicationController # rubocop:disable Metrics/ClassLength
        before_action :verify_access!

        def index
          bgs_claims = find_bgs_claims!

          lighthouse_claims = ClaimsApi::AutoEstablishedClaim.where(veteran_icn: target_veteran.mpi.icn)

          render json: [] && return unless bgs_claims || lighthouse_claims
          mapped_claims = map_claims(bgs_claims:, lighthouse_claims:)

          blueprint_options = { base_url: request.base_url, veteran_id: params[:veteranId], view: :index, root: :data }
          render json: ClaimsApi::V2::Blueprints::ClaimBlueprint.render(mapped_claims, blueprint_options)
        end

        def show
          lighthouse_claim = find_lighthouse_claim!(claim_id: params[:id])
          benefit_claim_id = lighthouse_claim.present? ? lighthouse_claim.evss_id : params[:id]
          bgs_claim = find_bgs_claim!(claim_id: benefit_claim_id)

          if lighthouse_claim.blank? && bgs_claim.blank?
            raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claim not found')
          end

          validate_id_with_icn(bgs_claim, lighthouse_claim, params[:veteranId])

          output = generate_show_output(bgs_claim:, lighthouse_claim:)
          blueprint_options = { base_url: request.base_url, veteran_id: params[:veteranId], view: :show, root: :data }

          render json: ClaimsApi::V2::Blueprints::ClaimBlueprint.render(output, blueprint_options)
        end

        private

        def evss_docs_service
          EVSS::DocumentsService.new(auth_headers)
        end

        def bgs_phase_status_mapper
          ClaimsApi::BGSClaimStatusMapper.new
        end

        def validate_id_with_icn(bgs_claim, lighthouse_claim, request_icn)
          claim_prtcpnt_id = if bgs_claim&.dig(:benefit_claim_details_dto).present?
                               bgs_claim&.dig(:benefit_claim_details_dto, :ptcpnt_vet_id)
                             end
          veteran_icn = if lighthouse_claim.present? && lighthouse_claim['veteran_icn'].present?
                          lighthouse_claim['veteran_icn']
                        end

          if claim_prtcpnt_id != target_veteran.participant_id && veteran_icn != request_icn
            raise ::Common::Exceptions::ResourceNotFound.new(
              detail: 'Invalid claim ID for the veteran identified.'
            )
          end
        end

        def generate_show_output(bgs_claim:, lighthouse_claim:) # rubocop:disable Metrics/MethodLength
          if lighthouse_claim.present? && bgs_claim.present?
            bgs_details = bgs_claim[:benefit_claim_details_dto]
            structure = build_claim_structure(
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
            structure = build_claim_structure(data: bgs_details,
                                              lighthouse_id: nil,
                                              upstream_id: bgs_details[:benefit_claim_id])
          end
          structure.merge!(errors: get_errors(lighthouse_claim))
          structure.merge!(supporting_documents: build_supporting_docs(bgs_claim))
          structure.merge!(tracked_items: map_bgs_tracked_items(bgs_claim))
          structure.merge!(build_claim_phase_attributes(bgs_claim, 'show'))
        end

        def map_claims(bgs_claims:, lighthouse_claims:) # rubocop:disable Metrics/MethodLength
          mapped_claims = (bgs_claims&.dig(:benefit_claims_dto, :benefit_claim) || []).map do |bgs_claim|
            matching_claim = find_bgs_claim_in_lighthouse_collection(
              lighthouse_collection: lighthouse_claims,
              bgs_claim:
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
              status: bgs_phase_status_mapper.name(remaining_claim)
            }
          end
          mapped_claims
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

          local_bgs_service.find_benefit_claim_details_by_benefit_claim_id(
            claim_id
          )
        end

        def find_bgs_claims!
          local_bgs_service.find_benefit_claims_status_by_ptcpnt_id(
            target_veteran.participant_id
          )
        end

        def find_tracked_items!(claim_id)
          return if claim_id.blank?

          local_bgs_service.find_tracked_items(claim_id)[:dvlpmt_items] || []
        end

        def looking_for_lighthouse_claim?(claim_id:)
          claim_id.to_s.include?('-')
        end

        def build_claim_structure(data:, lighthouse_id:, upstream_id:) # rubocop:disable Metrics/MethodLength
          {
            claim_date: date_present(data[:claim_dt]),
            claim_id: upstream_id,
            claim_phase_dates: build_claim_phase_attributes(data, 'index'),
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

        def get_phase_type_indicator_array(data)
          return if data[:benefit_claim_details_dto][:phase_type_change_ind].nil?

          data = data[:benefit_claim_details_dto][:phase_type_change_ind]
          data.split('')
        end

        def current_phase_back(data)
          return false if data[:benefit_claim_details_dto][:phase_type_change_ind].nil?

          pt_ind_array = get_phase_type_indicator_array(data)
          pt_ind_array.first.to_i > pt_ind_array.last.to_i
        end

        def latest_phase_type(data)
          return if data&.dig(:benefit_claim_details_dto, :bnft_claim_lc_status).nil?

          if data&.dig(:benefit_claim_details_dto, :bnft_claim_lc_status).is_a?(Array)
            data[:benefit_claim_details_dto][:bnft_claim_lc_status][0][:phase_type]
          elsif data&.dig(:benefit_claim_details_dto, :bnft_claim_lc_status, :phase_type)
            data[:benefit_claim_details_dto][:bnft_claim_lc_status][:phase_type]
          else
            pt_ind_array = get_phase_type_indicator_array(data)
            mapper.get_phase_from_phase_type_ind(pt_ind_array.last)
          end
        end

        def get_current_status_from_hash(data)
          if data&.dig('benefit_claim_details_dto', 'bnft_claim_lc_status').present?
            data[:benefit_claim_details_dto][:bnft_claim_lc_status].last do |lc|
              phase_number = get_phase_number_from_phase_details(lc)
              bgs_phase_status_mapper.name(lc[:phase_type], phase_number || nil)
            end
          elsif data&.dig(:phase_type).present?
            bgs_phase_status_mapper.name(data[:phase_type])
          end
        end

        def get_phase_number_from_phase_details(details)
          if details[:phase_type_change_ind].present?
            details[:phase_type_change_ind] == 'N' ? '1' : details[:phase_type_change_ind].split('').last
          end
        end

        def get_completed_phase_number_from_phase_details(details)
          if details[:phase_type_change_ind].present?
            return if details[:phase_type_change_ind] == 'N'

            details[:phase_type_change_ind].split('').first
          end
        end

        def get_bgs_phase_completed_dates(data)
          phase_dates = {}

          if data&.dig(:benefit_claim_details_dto, :bnft_claim_lc_status).is_a?(Array)
            max_completed_phase = 0
            data[:benefit_claim_details_dto][:bnft_claim_lc_status].each_with_index do |lc, i|
              completed_phase_number = get_completed_phase_number_from_phase_details(lc)
              if i.zero?
                max_completed_phase = completed_phase_number
                phase_dates["phase#{completed_phase_number}CompleteDate"] = date_present(lc[:phase_chngd_dt])
              elsif completed_phase_number.present? && completed_phase_number < max_completed_phase
                phase_dates["phase#{completed_phase_number}CompleteDate"] = date_present(lc[:phase_chngd_dt])
              end
            end
          else
            date = data[:benefit_claim_details_dto][:bnft_claim_lc_status][:phase_chngd_dt]
            phase_dates['phase1CompleteDate'] = date_present(date)
          end

          phase_dates
        end

        def extract_date(bgs_details)
          bgs_details.is_a?(Array) ? bgs_details.first[:phase_chngd_dt] : bgs_details[:phase_chngd_dt]
        end

        ### called from inside of format_bgs_phase_date & format_bgs_phase_chng_dates
        ### calls format_bgs_date
        def date_present(date)
          return unless date.is_a?(Date) || date.is_a?(String)

          date.present? ? format_bgs_date(date) : nil
        end

        def format_bgs_date(phase_change_date)
          d = Date.parse(phase_change_date.to_s)
          d.strftime('%Y-%m-%d')
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

          phase_data = if data[:phase_type].present?
                         data[:phase_type]
                       elsif data[:bnft_claim_lc_status].present?
                         data[:bnft_claim_lc_status]
                       else
                         data[:claim_status]
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
          phase_number = get_phase_number_from_phase_details(phase_data.last)
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

        def handle_array_or_hash(object, attribute)
          if object.present?
            object.is_a?(Array) ? object.pluck(attribute) : [object[attribute]]
          else
            []
          end
        end

        def map_bgs_tracked_items(bgs_claim) # rubocop:disable Metrics/MethodLength
          return [] if bgs_claim.nil?

          claim_id = bgs_claim.dig(:benefit_claim_details_dto, :benefit_claim_id)
          return [] if claim_id.nil?

          tracked_items = find_tracked_items!(claim_id)

          ebenefits_details = bgs_claim[:benefit_claim_details_dto]

          tracked_ids = handle_array_or_hash(tracked_items, :dvlpmt_item_id)

          # wwsnfy What We Still Need From You
          wwsnfy = handle_array_or_hash(ebenefits_details[:wwsnfy], :dvlpmt_item_id) || []
          # wwr What We Received From You and Others
          wwr = handle_array_or_hash(ebenefits_details[:wwr], :dvlpmt_item_id) || []
          # wwd What We Still Need From Others
          wwd = handle_array_or_hash(ebenefits_details[:wwd], :dvlpmt_item_id) || []

          # convert to array and flatten to prevent hashes from breaking this
          ebenefits_items = ([ebenefits_details[:wwsnfy]].flatten | [ebenefits_details[:wwr]].flatten |
                             [ebenefits_details[:wwd]].flatten).compact

          ids = tracked_ids | wwsnfy | wwr | wwd

          ids.map do |id|
            item = tracked_items.find do |t|
              if t.is_a?(Hash)
                t[:dvlpmt_item_id] == id
              else
                t.include?('dvlpmt_item_id') ? t[:dvlpmt_item_id] == id : nil
              end
            end || {}

            # Values for status enum: "ACCEPTED",
            # "INITIAL_REVIEW_COMPLETE",
            # "NEEDED_FROM_YOU",
            # "NEEDED_FROM_OTHERS",
            # "NO_LONGER_REQUIRED"
            # "SUBMITTED_AWAITING_REVIEW",

            if wwsnfy.include? id
              status = 'NEEDED_FROM_YOU'
            elsif wwd.include? id
              status = 'NEEDED_FROM_OTHERS'
            else
              status = 'SUBMITTED_AWAITING_REVIEW'

              if item.present?
                claim_status = [bgs_claim.dig(:benefit_claim_details_dto,
                                              :bnft_claim_lc_status)].flatten.first[:phase_type]
                status = if ['Preparation for Decision',
                             'Pending Decision Approval',
                             'Preparation for Notification',
                             'Complete'].include? claim_status
                           'ACCEPTED'
                         elsif ['CAN'].include? claim_status
                           'CANCELLED'
                         else
                           'INITIAL_REVIEW_COMPLETE'
                         end
              end
            end

            uploads_allowed = %w[NEEDED SUBMITTED_AWAITING_REVIEW INITIAL_REVIEW_COMPLETE].include?(status)

            {
              closed_date: date_present(item[:date_closed]),
              requested_date: tracked_item_req_date(ebenefits_details, item, id),
              received_date: date_present(item[:receive_dt]),
              description: tracked_item_description(ebenefits_items, id),
              display_name: item[:short_nm],
              overdue: item[:suspns_dt].nil? ? false : item[:suspns_dt] < Time.zone.now, # EVSS generates this field
              status:, # EVSS generates this field
              suspense_date: date_present(item[:suspns_dt]),
              tracked_item_id: id.to_i,
              uploaded: item[:receive_dt].present?, # EVSS generates this field
              uploads_allowed: # EVSS generates this field
            }
          end
        end

        def tracked_item_req_date(ebenefits_details, item, id)
          items = ([ebenefits_details[:wwsnfy]].flatten |
          [ebenefits_details[:wwr]].flatten |
          [ebenefits_details[:wwd]].flatten).compact

          tracked_item = items.find { |i| i[:dvlpmt_item_id] == id } || {}
          date_present(tracked_item[:date_open] || item[:req_dt] || item[:create_dt])
        end

        def tracked_item_description(tracked_items, id)
          return nil if tracked_items.nil?

          tracked_item = tracked_items.find { |a| a[:dvlpmt_item_id] == id }
          tracked_item.present? ? tracked_item[:items] : nil
        end

        def build_supporting_docs(bgs_claim)
          return [] if bgs_claim.nil?

          docs = if sandbox?
                   { documents: ClaimsApi::V2::MockDocumentsService.new.generate_documents }.with_indifferent_access
                 else
                   evss_docs_service.get_claim_documents(bgs_claim[:benefit_claim_details_dto][:benefit_claim_id]).body
                 end
          return [] if docs.nil? || docs['documents'].blank?

          docs['documents'].map do |doc|
            {
              document_id: doc['document_id'],
              document_type_label: doc['document_type_label'],
              original_file_name: doc['original_file_name'],
              tracked_item_id: doc['tracked_item_id'],
              upload_date: upload_date(doc['upload_date'])
            }
          end
        end

        def upload_date(upload_date)
          return if upload_date.nil?

          Time.zone.at(upload_date / 1000).strftime('%Y-%m-%d')
        end

        def build_claim_phase_attributes(bgs_claim, view)
          return {} if bgs_claim.nil?

          case view
          when 'show'
            {
              claim_phase_dates:
                {
                  phase_change_date: format_bgs_phase_chng_dates(bgs_claim[:benefit_claim_details_dto]),
                  current_phase_back: current_phase_back(bgs_claim),
                  latest_phase_type: latest_phase_type(bgs_claim),
                  previous_phases: get_bgs_phase_completed_dates(bgs_claim)
                }
            }
          when 'index'
            {
              phase_change_date: format_bgs_phase_chng_dates(bgs_claim)
            }
          end
        end

        def sandbox?
          Settings.claims_api.claims_error_reporting.environment_name&.downcase.eql? 'sandbox'
        end
      end
    end
  end
end
