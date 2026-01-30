# frozen_string_literal: true

require 'decision_reviews/v1//constants'
require 'decision_reviews/v1/helpers'
require 'decision_reviews/saved_claim/service'
module DecisionReviews
  module V1
    class SupplementalClaimsController < AppealsBaseController
      include DecisionReviews::V1::Helpers
      include DecisionReviews::SavedClaim::Service
      service_tag 'appeal-application'

      def show
        render json: decision_review_service.get_supplemental_claim(params[:id]).body
      rescue => e
        log_exception_to_personal_information_log(
          e, error_class: error_class(method: 'show', exception_class: e.class), id: params[:id]
        )
        raise
      end

      def create
        process_submission
      rescue => e
        ::Rails.logger.error(
          message: "Exception occurred while submitting Supplemental Claim: #{e.message}",
          backtrace: e.backtrace
        )
        handle_personal_info_error(e)
      end

      private

      def post_create_log_msg(appeal_submission_id:, submitted_appeal_uuid:)
        {
          message: 'Supplemental Claim Appeal Record Created',
          appeal_submission_id:,
          lighthouse_submission: {
            id: submitted_appeal_uuid
          }
        }
      end

      def handle_4142(request_body:, form4142:, appeal_submission_id:, submitted_appeal_uuid:) # rubocop:disable Naming/VariableNumber
        return if form4142.blank?

        rejiggered_payload = get_and_rejigger_required_info(request_body:, form4142:, user: @current_user)
        jid = decision_review_service.queue_form4142(appeal_submission_id:, rejiggered_payload:, submitted_appeal_uuid:)
        log_form4142_job_queued(appeal_submission_id, submitted_appeal_uuid, jid)
      end

      def log_form4142_job_queued(appeal_submission_id, submitted_appeal_uuid, jid)
        ::Rails.logger.info({
                              form_id: DecisionReviews::V1::FORM4142_ID,
                              parent_form_id: DecisionReviews::V1::SUPP_CLAIM_FORM_ID,
                              message: 'Supplemental Claim Form4142 queued.',
                              jid:,
                              appeal_submission_id:,
                              lighthouse_submission: {
                                id: submitted_appeal_uuid
                              }
                            })
      end

      def submit_evidence(sc_evidence, appeal_submission_id, submitted_appeal_uuid)
        # I know I could just use `appeal_submission.enqueue_uploads` here, but I want to return the jids to log, so
        # replicating instead. There is some duplicate code but I want them jids in the logs.
        jids = decision_review_service.queue_submit_evidence_uploads(sc_evidence, appeal_submission_id)
        ::Rails.logger.info({
                              form_id: DecisionReviews::V1::SUPP_CLAIM_FORM_ID,
                              message: 'Supplemental Claim Evidence jobs created.',
                              appeal_submission_id:,
                              lighthouse_submission: {
                                id: submitted_appeal_uuid
                              },
                              evidence_upload_job_ids: jids
                            })
      end

      def handle_personal_info_error(e)
        request = begin
          { body: request_body_hash }
        rescue
          request_body_debug_data
        end
        log_exception_to_personal_information_log(
          e, error_class: error_class(method: 'create', exception_class: e.class), request:
        )
        raise
      end

      def process_submission
        req_body_obj = request_body_hash.is_a?(String) ? JSON.parse(request_body_hash) : request_body_hash

        if Flipper.enabled?(:decision_review_sc_redesign_nov2025, @current_user) && req_body_obj['scRedesign']
          req_body_obj = format_evidence_data_for_lighthouse_schema(req_body_obj)
          formatted_private_evidence = format_private_evidence_entries(req_body_obj['form4142'])
          req_body_obj['form4142'] = formatted_private_evidence
        end

        # For now, we have to address schema issues before serializing, since our SavedClaim model
        # uses a copy of the same Lighthouse schema to validate the data before saving.
        normalize_evidence_retrieval_for_lighthouse_schema(req_body_obj)

        req_body_obj = normalize_area_code_for_lighthouse_schema(req_body_obj)
        saved_claim_request_body = req_body_obj.to_json
        form4142 = req_body_obj.delete('form4142')
        sc_evidence = req_body_obj.delete('additionalDocuments')
        zip_from_frontend = req_body_obj.dig('data', 'attributes', 'veteran', 'address', 'zipCode5')

        sc_response = decision_review_service.create_supplemental_claim(request_body: req_body_obj, user: @current_user)
        submitted_appeal_uuid = sc_response.body.dig('data', 'id')

        ActiveRecord::Base.transaction do
          appeal_submission_id = create_appeal_submission(submitted_appeal_uuid, zip_from_frontend)
          handle_saved_claim(form: saved_claim_request_body, guid: submitted_appeal_uuid, form4142:)

          ::Rails.logger.info(post_create_log_msg(appeal_submission_id:, submitted_appeal_uuid:))
          handle_4142(request_body: req_body_obj, form4142:, appeal_submission_id:, submitted_appeal_uuid:)
          submit_evidence(sc_evidence, appeal_submission_id, submitted_appeal_uuid) if sc_evidence.present?

          # Only destroy InProgressForm after evidence upload step
          # so that we still have references if a fatal error occurs before this step
          clear_in_progress_form
        end
        render json: sc_response.body, status: sc_response.status
      end

      # Schema reference: https://github.com/department-of-veterans-affairs/vets-json-schema/blob/master/src/schemas/SC-create-request-body_v1/schema.json#L193-L201
      def set_evidence_types(evidence_submission, has_uploaded_evidence, has_va_evidence)
        evidence_submission['evidenceType'] << 'retrieval' if has_va_evidence
        evidence_submission['evidenceType'] << 'upload' if has_uploaded_evidence

        evidence_submission['evidenceType'] << 'none' if !has_uploaded_evidence && !has_va_evidence

        evidence_submission
      end

      # Schema reference: https://github.com/department-of-veterans-affairs/vets-json-schema/blob/master/src/schemas/SC-create-request-body_v1/schema.json#L173-L192
      def set_treatment_locations(evidence_submission, req_body_obj)
        treatment_locations = req_body_obj.dig('data', 'attributes', 'treatmentLocations')
        treatment_location_other = req_body_obj.dig('data', 'attributes', 'treatmentLocationOther')

        if treatment_locations.is_a?(Array) && treatment_locations.any?
          evidence_submission['treatmentLocations'] =
            treatment_locations
        end

        if treatment_location_other.is_a?(String) && !treatment_location_other.empty?
          evidence_submission['treatmentLocationOther'] =
            treatment_location_other
        end

        # Remove treatmentLocations and treatmentLocationOther from their original location
        # since they have moved into evidenceSubmission
        req_body_obj['data']['attributes'].delete('treatmentLocations')
        req_body_obj['data']['attributes'].delete('treatmentLocationOther')

        evidence_submission
      end

      # Schema reference: https://github.com/department-of-veterans-affairs/vets-json-schema/blob/master/src/schemas/SC-create-request-body_v1/schema.json#L203-L238
      def set_va_evidence(evidence_submission, va_evidence)
        formatted_va_evidence = format_va_evidence_entries(va_evidence)

        evidence_submission['retrieveFrom'] = formatted_va_evidence
        evidence_submission
      end

      # For the new array builder UI, we are passing the raw FE evidence data as-is to the BE,
      # so we need to transform it to match the Lighthouse schema here
      def format_evidence_data_for_lighthouse_schema(req_body_obj)
        evidence_submission = {
          'evidenceType' => []
        }

        uploaded_evidence = req_body_obj['additionalDocuments']
        va_evidence = req_body_obj.dig('data', 'attributes', 'vaEvidence')

        has_uploaded_evidence = uploaded_evidence.is_a?(Array) && uploaded_evidence.any?
        has_va_evidence = va_evidence.is_a?(Array) && va_evidence.any?

        set_evidence_types(evidence_submission, has_uploaded_evidence, has_va_evidence)
        set_treatment_locations(evidence_submission, req_body_obj)

        set_va_evidence(evidence_submission, va_evidence) if has_va_evidence

        req_body_obj['data']['attributes']['evidenceSubmission'] = evidence_submission

        # Remove vaEvidence from its original location since it has moved into evidenceSubmission
        req_body_obj['data']['attributes'].delete('vaEvidence')

        req_body_obj
      end

      def create_appeal_submission(submitted_appeal_uuid, backup_zip)
        upload_metadata = DecisionReviews::V1::Service.file_upload_metadata(
          @current_user, backup_zip
        )
        create_params = {
          user_account: @current_user.user_account,
          type_of_appeal: 'SC',
          submitted_appeal_uuid:,
          upload_metadata:
        }
        appeal_submission = AppealSubmission.create!(create_params)
        appeal_submission.id
      end

      def handle_saved_claim(form:, guid:, form4142:)
        uploaded_forms = []
        uploaded_forms << '21-4142' if form4142.present?
        store_saved_claim(claim_class: ::SavedClaim::SupplementalClaim, form:, guid:, uploaded_forms:)
      end

      def clear_in_progress_form
        InProgressForm.form_for_user('20-0995', @current_user)&.destroy!
      end

      def error_class(method:, exception_class:)
        "#{self.class.name}##{method} exception #{exception_class} (SC_V1)"
      end

      # To conform to the LH schema, we need to ensure that if the evidenceType includes 'retrieval',
      # then the retrieveFrom array must have facilities with unique facility location names
      def normalize_evidence_retrieval_for_lighthouse_schema(req_body_obj)
        evidence_submission = req_body_obj.dig('data', 'attributes', 'evidenceSubmission')
        evidence_type = evidence_submission&.dig('evidenceType')
        retrieve_from = evidence_submission&.dig('retrieveFrom')
        # Return if evidenceType is nil or doesn't include 'retrieval'
        return req_body_obj unless evidence_type.is_a?(Array) && evidence_type.include?('retrieval')
        # Return if retrieveFrom is nil, not an array, or only one item
        return req_body_obj unless retrieve_from.is_a?(Array) && retrieve_from.length > 1

        grouped_entries = retrieve_from.group_by do |entry|
          entry.dig('attributes', 'locationAndName')
        end

        merged_entries = grouped_entries.map do |_, entries|
          if entries.length == 1
            entries.first
          else
            merge_evidence_entries(entries)
          end
        end

        req_body_obj['data']['attributes']['evidenceSubmission']['retrieveFrom'] = merged_entries
        req_body_obj
      end

      def merge_evidence_entries(entries)
        merged_entry = entries.first.deep_dup
        merged_attributes = merged_entry['attributes']

        all_evidence_dates = []
        entries.each do |entry|
          attributes = entry['attributes']
          if attributes && attributes['evidenceDates'].is_a?(Array)
            all_evidence_dates.concat(attributes['evidenceDates'])
          end
        end

        unique_evidence_dates = all_evidence_dates.uniq.sort_by { |date_range| date_range['startDate'] }

        # Apply schema constraints (maxItems: 4) -- this should be unlikely,
        # as we should only be collecting dates for pre-2005 treatment
        unique_evidence_dates = unique_evidence_dates.first(4)

        # Only set evidenceDates if we have dates to include
        # Lighthouse accepts missing evidenceDates key but rejects empty array
        merged_attributes['evidenceDates'] = unique_evidence_dates unless unique_evidence_dates.empty?
        merged_entry
      end
    end
  end
end
