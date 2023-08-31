# frozen_string_literal: true

require 'claims_api/bgs_claim_status_mapper'
require 'claims_api/v2/mock_documents_service'

module ClaimsApi
  module V2
    module Veterans
      class ClaimsController < ClaimsApi::V2::ApplicationController # rubocop:disable Metrics/ClassLength
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
          ClaimsApi::Logger.log('EVSS', rid: request.request_id, detail: 'starting service')
          service = EVSS::DocumentsService.new(auth_headers)
          ClaimsApi::Logger.log('EVSS', rid: request.request_id, detail: 'service started')
          service
        end

        def bgs_phase_status_mapper
          ClaimsApi::BGSClaimStatusMapper.new
        end

        def validate_id_with_icn(bgs_claim, lighthouse_claim, request_icn)
          if bgs_claim&.dig(:benefit_claim_details_dto).present?
            clm_prtcpnt_vet_id = bgs_claim&.dig(:benefit_claim_details_dto, :ptcpnt_vet_id)
            clm_prtcpnt_clmnt_id = bgs_claim&.dig(:benefit_claim_details_dto, :ptcpnt_clmant_id)
          end

          veteran_icn = if lighthouse_claim.present? && lighthouse_claim['veteran_icn'].present?
                          lighthouse_claim['veteran_icn']
                        end

          if clm_prtcpnt_cannot_access_claim?(clm_prtcpnt_vet_id, clm_prtcpnt_clmnt_id) && veteran_icn != request_icn
            raise ::Common::Exceptions::ResourceNotFound.new(
              detail: 'Invalid claim ID for the veteran identified.'
            )
          end
        end

        def clm_prtcpnt_cannot_access_claim?(clm_prtcpnt_vet_id, clm_prtcpnt_clmnt_id)
          return true if clm_prtcpnt_vet_id.nil? || clm_prtcpnt_clmnt_id.nil?

          # if either of these is false then we have a match and can show the record
          clm_prtcpnt_vet_id != target_veteran.participant_id && clm_prtcpnt_clmnt_id != target_veteran.participant_id
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
          extracted_claims = [bgs_claims&.dig(:benefit_claims_dto, :benefit_claim)].flatten.compact
          mapped_claims = extracted_claims.map do |bgs_claim|
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
            base_end_prdct_type_cd: data[:base_end_prdct_type_cd],
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

        def current_phase_back(data)
          lc_status_array = [data&.dig(:benefit_claim_details_dto, :bnft_claim_lc_status)].flatten
          return false if lc_status_array.nil?

          return false if lc_status_array.first&.dig(:phase_type_change_ind).nil?

          indicator = latest_phase_type_change_indicator(data).split('')
          return false if indicator == 'N'

          indicator.first.to_i > indicator.last.to_i
        end

        def latest_phase_type_change_indicator(data)
          [data&.dig(:benefit_claim_details_dto, :bnft_claim_lc_status)].flatten.first&.dig(:phase_type_change_ind)
        end

        def latest_phase_type(data)
          return if data&.dig(:benefit_claim_details_dto, :bnft_claim_lc_status).nil?

          latest = [data&.dig(:benefit_claim_details_dto, :bnft_claim_lc_status)].flatten.first&.dig(:phase_type)
          return bgs_phase_status_mapper.get_phase_type_from_dictionary(latest.downcase) unless latest.nil?

          indicator = latest_phase_type_change_indicator(data).split('')
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

            details[:phase_type_change_ind].split('').first
          end
        end

        def get_bgs_phase_completed_dates(data)
          lc_status_array =
            [data&.dig(:benefit_claim_details_dto, :bnft_claim_lc_status)].flatten.compact
          return {} if lc_status_array.first.nil?

          max_completed_phase = lc_status_array.first[:phase_type_change_ind].split('').first
          return {} if max_completed_phase.downcase.eql?('n')

          {}.tap do |phase_date|
            lc_status_array.reverse.map do |phase|
              completed_phase_number = phase[:phase_type_change_ind].split('').first
              if completed_phase_number <= max_completed_phase &&
                 completed_phase_number.to_i.positive?
                phase_date["phase#{completed_phase_number}CompleteDate"] = date_present(phase[:phase_chngd_dt])
              end
            end
          end.sort.reverse.to_h
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

        def map_bgs_tracked_items(bgs_claim)
          return [] if bgs_claim.nil?

          claim_id = bgs_claim.dig(:benefit_claim_details_dto, :benefit_claim_id)
          return [] if claim_id.nil?

          @tracked_items = find_tracked_items!(claim_id)

          return [] if @tracked_items.blank?

          @ebenefits_details = bgs_claim[:benefit_claim_details_dto]

          (build_wwsnfy_items | build_wwd_items | build_wwr_items | build_no_longer_needed_items).sort_by do |list_item|
            list_item[:id]
          end
        end

        def map_status(item_id, unique_status)
          if supporting_document?(item_id)
            'SUBMITTED_AWAITING_REVIEW'
          else
            unique_status
          end
        end

        def build_wwsnfy_items
          # wwsnfy What We Still Need From You
          wwsnfy = [@ebenefits_details[:wwsnfy]].flatten.compact
          return [] if wwsnfy.empty?

          wwsnfy.map do |item|
            status = map_status(item[:dvlpmt_item_id], 'NEEDED_FROM_YOU')

            build_tracked_item(find_tracked_item(item[:dvlpmt_item_id]), status, item, wwsnfy: true)
          end
        end

        def build_wwd_items
          # wwd What We Still Need From Others
          wwd = [@ebenefits_details[:wwd]].flatten.compact
          return [] if wwd.empty?

          wwd.map do |item|
            status = map_status(item[:dvlpmt_item_id], 'NEEDED_FROM_OTHERS')

            build_tracked_item(find_tracked_item(item[:dvlpmt_item_id]), status, item)
          end
        end

        def build_wwr_items
          # wwr What We Received From You and Others
          wwr = [@ebenefits_details[:wwr]].flatten.compact
          return [] if wwr.empty?

          claim_status_type = [@ebenefits_details[:bnft_claim_lc_status]].flatten.first[:phase_type]

          wwr.map do |item|
            status = accepted?(claim_status_type) ? 'ACCEPTED' : 'INITIAL_REVIEW_COMPLETE'

            build_tracked_item(find_tracked_item(item[:dvlpmt_item_id]), status, item)
          end
        end

        def build_no_longer_needed_items
          no_longer_needed = [@tracked_items].flatten.compact.select do |item|
            item[:accept_dt].present? && item[:dvlpmt_tc] == 'CLMNTRQST'
          end
          return [] if no_longer_needed.empty?

          no_longer_needed.map do |tracked_item|
            status = 'NO_LONGER_REQUIRED'

            build_tracked_item(tracked_item, status, {})
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

        def build_tracked_item(tracked_item, status, item, wwsnfy: false)
          uploads_allowed = uploads_allowed?(status)
          {
            closed_date: date_present(tracked_item[:accept_dt]),
            description: item[:items],
            display_name: tracked_item[:short_nm],
            overdue: overdue?(tracked_item, wwsnfy),
            received_date: date_present(tracked_item[:receive_dt]),
            requested_date: tracked_item_req_date(tracked_item, item),
            status:,
            suspense_date: date_present(tracked_item[:suspns_dt]),
            id: tracked_item[:dvlpmt_item_id].to_i,
            uploads_allowed:
          }
        end

        def supporting_document?(id)
          @supporting_documents.find { |doc| doc['tracked_item_id'] == id.to_i }.present?
        end

        def find_tracked_item(id)
          [@tracked_items].flatten.compact.find { |item| item[:dvlpmt_item_id] == id }
        end

        def tracked_item_req_date(tracked_item, item)
          date_present(item[:date_open] || tracked_item[:req_dt] || tracked_item[:create_dt])
        end

        def get_evss_documents(claim_id)
          ClaimsApi::Logger.log('EVSS', rid: request.request_id, detail: 'getting docs')
          docs = evss_docs_service.get_claim_documents(claim_id).body
          ClaimsApi::Logger.log('EVSS', rid: request.request_id, detail: 'got docs')
          docs
        rescue => e
          ClaimsApi::Logger.log('EVSS', rid: request.request_id, detail: 'getting docs failed', exception: e)
          log_message_to_sentry('Error in Claims v2 show calling EVSS Doc Service',
                                :warning,
                                body: e.message)
          {}
        end

        # rubocop:disable Metrics/MethodLength
        def build_supporting_docs(bgs_claim)
          return [] if bgs_claim.nil?

          @supporting_documents = []

          docs = if benefits_documents_enabled?
                   file_number = local_bgs_service.find_by_ssn(target_veteran.ssn)&.dig(:file_nbr) # rubocop:disable Rails/DynamicFindBy

                   if file_number.nil?
                     raise ::Common::Exceptions::ResourceNotFound.new(detail:
                       "Unable to locate Veteran's File Number. " \
                       'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.')
                   end
                   ClaimsApi::Logger.log('benefits_documents',
                                         detail: "calling benefits documents api for claim_id #{params[:id]}")
                   supporting_docs_list = benefits_doc_api(multipart: false).search(params[:id],
                                                                                    file_number)&.dig(:data)
                   # add with_indifferent_access so ['documents'] works below
                   # we can remove when EVSS is gone and access it via it's symbol
                   supporting_docs_list.with_indifferent_access if supporting_docs_list.present?
                 elsif sandbox?
                   { documents: ClaimsApi::V2::MockDocumentsService.new.generate_documents }.with_indifferent_access
                 else
                   get_evss_documents(bgs_claim[:benefit_claim_details_dto][:benefit_claim_id])
                 end
          return [] if docs.nil? || docs&.dig('documents').blank?

          @supporting_documents = docs['documents']

          docs['documents'].map do |doc|
            doc = doc.transform_keys(&:underscore) if benefits_documents_enabled?
            upload_date = upload_date(doc['upload_date']) || bd_upload_date(doc['uploaded_date_time'])
            {
              document_id: doc['document_id'],
              document_type_label: doc['document_type_label'],
              original_file_name: doc['original_file_name'],
              tracked_item_id: doc['tracked_item_id'],
              upload_date:
            }
          end
        end
        # rubocop:enable Metrics/MethodLength

        # duplicating temporarily to bd_upload_date. remove when EVSS call is gone
        def upload_date(upload_date)
          return if upload_date.nil?

          Time.zone.at(upload_date / 1000).strftime('%Y-%m-%d')
        end

        def bd_upload_date(upload_date)
          return if upload_date.nil?

          Date.parse(upload_date).strftime('%Y-%m-%d')
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

        def benefits_documents_enabled?
          Flipper.enabled? :claims_status_v2_lh_benefits_docs_service_enabled
        end
      end
    end
  end
end
