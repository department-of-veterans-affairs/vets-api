# frozen_string_literal: true

require 'benefits_claims/title_generator'
require 'lighthouse/benefits_claims/service'
require 'lighthouse/benefits_claims/constants'
require 'lighthouse/benefits_documents/constants'
require 'lighthouse/benefits_claims/utilities/helpers'
require 'lighthouse/benefits_documents/documents_status_polling_service'
require 'lighthouse/benefits_documents/update_documents_status_service'

module V0
  class BenefitsClaimsController < ApplicationController
    include InboundRequestLogging
    include V0::Concerns::MultiProviderSupport
    before_action { authorize :lighthouse, :access? }
    before_action :log_request_origin
    service_tag 'claims-shared'

    STATSD_METRIC_PREFIX = 'api.benefits_claims'
    STATSD_TAGS = [
      'service:benefits-claims',
      'team:cross-benefits-crew',
      'team:benefits',
      'itportfolio:benefits-delivery',
      'dependency:lighthouse'
    ].freeze

    FEATURE_USE_TITLE_GENERATOR_WEB = 'cst_use_claim_title_generator_web'
    FEATURE_MULTI_CLAIM_PROVIDER = 'cst_multi_claim_provider'

    def index
      claims = if Flipper.enabled?(FEATURE_MULTI_CLAIM_PROVIDER, @current_user)
                 get_claims_from_providers
               else
                 service.get_claims
               end

      check_for_birls_id
      check_for_file_number

      claims['data'].each do |claim|
        update_claim_type_language(claim)
      end

      claim_ids = claims['data'].map { |claim| claim['id'] }
      evidence_submissions = fetch_evidence_submissions(claim_ids, 'index')

      if Flipper.enabled?(:cst_show_document_upload_status, @current_user)
        add_evidence_submissions_to_claims(claims['data'], evidence_submissions, 'index')
      end

      tap_claims(claims['data'])

      report_evidence_submission_metrics('index', evidence_submissions)

      render json: claims
    end

    def show
      claim = if Flipper.enabled?(FEATURE_MULTI_CLAIM_PROVIDER, @current_user)
                get_claim_from_providers(params[:id], params[:type])
              else
                service.get_claim(params[:id])
              end
      update_claim_type_language(claim['data'])

      # Manual status override for certain tracked items
      # See https://github.com/department-of-veterans-affairs/va.gov-team/issues/101447
      # This should be removed when the items are re-categorized by BGS
      # We are not doing this in the Lighthouse service because we want web and mobile to have
      # separate rollouts and testing.
      claim = rename_rv1(claim)

      # https://github.com/department-of-veterans-affairs/va.gov-team/issues/98364
      # This should be removed when the items are removed by BGS
      claim = suppress_evidence_requests(claim) if Flipper.enabled?(:cst_suppress_evidence_requests_website)

      # Document uploads to EVSS require a birls_id; This restriction should
      # be removed when we move to Lighthouse Benefits Documents for document uploads
      claim['data']['attributes']['canUpload'] = !@current_user.birls_id.nil?

      evidence_submissions = fetch_evidence_submissions(claim['data']['id'], 'show')

      if Flipper.enabled?(:cst_show_document_upload_status, @current_user)
        update_evidence_submissions_for_claim(claim['data']['id'], evidence_submissions)
        add_evidence_submissions_to_claims([claim['data']], evidence_submissions, 'show')
      end

      # We want to log some details about claim type patterns to track in DataDog
      log_claim_details(claim['data']['attributes'])

      tap_claims([claim['data']])

      report_evidence_submission_metrics('show', evidence_submissions)

      render json: claim
    end

    def submit5103
      # Log if the user doesn't have a file number
      # NOTE: We are treating the BIRLS ID as a substitute
      # for file number here
      ::Rails.logger.info('[5103 Submission] No file number') if @current_user.birls_id.nil?

      json_payload = request.body.read

      data = JSON.parse(json_payload)

      tracked_item_id = data['trackedItemId'] || nil

      res = service.submit5103(params[:id], tracked_item_id)

      render json: res
    end

    def failed_upload_evidence_submissions
      if Flipper.enabled?(:cst_show_document_upload_status, @current_user)
        render json: { data: filter_failed_evidence_submissions }
      else
        render json: { data: [] }
      end
    end

    private

    def log_request_origin
      return unless Flipper.enabled?(:log_claims_request_origin)

      log_inbound_request(message_type: 'lh.cst.inbound_request', message: 'Inbound request (Lighthouse claim status)')
    end

    def failed_evidence_submissions
      @failed_evidence_submissions ||= EvidenceSubmission.failed.where(user_account: current_user_account.id)
    end

    def current_user_account
      UserAccount.find(@current_user.user_account_uuid)
    end

    def claims_scope
      EVSSClaim.for_user(@current_user)
    end

    def service
      @service ||= BenefitsClaims::Service.new(@current_user)
    end

    def check_for_birls_id
      ::Rails.logger.info('[BenefitsClaims#index] No birls id') if current_user.birls_id.nil?
    end

    def check_for_file_number
      bgs_file_number = BGS::People::Request.new.find_person_by_participant_id(user: current_user).file_number
      ::Rails.logger.info('[BenefitsClaims#index] No file number') if bgs_file_number.blank?
    end

    def tap_claims(claims)
      claims.each do |claim|
        record = claims_scope.where(evss_id: claim['id']).first

        if record.blank?
          EVSSClaim.create(
            user_uuid: @current_user.uuid,
            user_account: @current_user.user_account,
            evss_id: claim['id'],
            data: {}
          )
        else
          # If there is a record, we want to set the updated_at field
          # to Time.zone.now
          record.touch # rubocop:disable Rails/SkipsModelValidations
        end
      end
    end

    def update_claim_type_language(claim)
      if Flipper.enabled?(:cst_use_claim_title_generator_web)
        # Adds displayTitle and claimTypeBase to the claim response object
        BenefitsClaims::TitleGenerator.update_claim_title(claim)
      end

      # always map "Death" claimType to "expenses related to death or burial"
      # TODO: #131812 [CST/MyVA] Remove claimType mapping from api responses (blocked)
      language_map = BenefitsClaims::Constants::CLAIM_TYPE_LANGUAGE_MAP
      if language_map.key?(claim.dig('attributes', 'claimType'))
        claim['attributes']['claimType'] = language_map[claim['attributes']['claimType']]
      end
    end

    def add_evidence_submissions(claim, evidence_submissions)
      non_duplicate_submissions = filter_duplicate_evidence_submissions(evidence_submissions, claim)
      tracked_items = claim['attributes']['trackedItems']
      non_duplicate_submissions.map { |es| build_filtered_evidence_submission_record(es, tracked_items) }
    end

    def filter_duplicate_evidence_submissions(evidence_submissions, claim)
      supporting_documents = claim['attributes']['supportingDocuments'] || []
      received_file_names = supporting_documents.map { |doc| doc['originalFileName'] }.compact

      return evidence_submissions if received_file_names.empty?

      evidence_submissions.reject do |evidence_submission|
        file_name = extract_evidence_submission_file_name(evidence_submission)
        file_name && received_file_names.include?(file_name)
      end
    end

    def extract_evidence_submission_file_name(evidence_submission)
      return nil if evidence_submission.template_metadata.nil?

      metadata = JSON.parse(evidence_submission.template_metadata)
      personalisation = metadata['personalisation']

      if personalisation.is_a?(Hash) && personalisation['file_name']
        personalisation['file_name']
      else
        ::Rails.logger.warn(
          '[BenefitsClaimsController] Missing or invalid personalisation in evidence submission metadata',
          { evidence_submission_id: evidence_submission.id }
        )
        nil
      end
    rescue JSON::ParserError, TypeError
      ::Rails.logger.error(
        '[BenefitsClaimsController] Error parsing evidence submission metadata',
        { evidence_submission_id: evidence_submission.id }
      )
      nil
    end

    def filter_failed_evidence_submissions
      filtered_evidence_submissions = []
      claims = {}

      failed_evidence_submissions.each do |es|
        # When we get a claim we add it to claims so that we prevent calling lighthouse multiple times
        # to get the same claim.
        claim = claims[es.claim_id]

        if claim.nil?
          claim = service.get_claim(es.claim_id)
          claims[es.claim_id] = claim
        end

        tracked_items = claim['data']['attributes']['trackedItems']

        filtered_evidence_submissions.push(build_filtered_evidence_submission_record(es, tracked_items))
      end

      filtered_evidence_submissions
    end

    def build_filtered_evidence_submission_record(evidence_submission, tracked_items)
      personalisation = JSON.parse(evidence_submission.template_metadata)['personalisation']
      tracked_item_display_name = BenefitsClaims::Utilities::Helpers.get_tracked_item_display_name(
        evidence_submission.tracked_item_id,
        tracked_items
      )
      tracked_item_friendly_name = BenefitsClaims::Constants::FRIENDLY_DISPLAY_MAPPING[tracked_item_display_name]

      { acknowledgement_date: evidence_submission.acknowledgement_date,
        claim_id: evidence_submission.claim_id,
        created_at: evidence_submission.created_at,
        delete_date: evidence_submission.delete_date,
        document_type: personalisation['document_type'],
        failed_date: evidence_submission.failed_date,
        file_name: personalisation['file_name'],
        id: evidence_submission.id,
        lighthouse_upload: evidence_submission.job_class == 'Lighthouse::EvidenceSubmissions::DocumentUpload',
        tracked_item_id: evidence_submission.tracked_item_id,
        tracked_item_display_name:,
        tracked_item_friendly_name:,
        upload_status: evidence_submission.upload_status,
        va_notify_status: evidence_submission.va_notify_status }
    end

    def log_claim_details(claim_info)
      ::Rails.logger.info('Claim Type Details',
                          { message_type: 'lh.cst.claim_types',
                            claim_type: claim_info['claimType'],
                            claim_type_code: claim_info['claimTypeCode'],
                            num_contentions: claim_info['contentions'].count,
                            ep_code: claim_info['endProductCode'],
                            current_phase_back: claim_info['claimPhaseDates']['currentPhaseBack'],
                            latest_phase_type: claim_info['claimPhaseDates']['latestPhaseType'],
                            decision_letter_sent: claim_info['decisionLetterSent'],
                            development_letter_sent: claim_info['developmentLetterSent'],
                            claim_id: params[:id] })
      log_evidence_requests(params[:id], claim_info)
    end

    def log_evidence_requests(claim_id, claim_info)
      tracked_items = claim_info['trackedItems']

      tracked_items.each do |ti|
        ::Rails.logger.info('Evidence Request Types',
                            { message_type: 'lh.cst.evidence_requests',
                              claim_id:,
                              tracked_item_id: ti['id'],
                              tracked_item_type: ti['displayName'],
                              tracked_item_status: ti['status'] })
      end
    end

    def rename_rv1(claim)
      tracked_items = claim.dig('data', 'attributes', 'trackedItems')
      tracked_items&.select { |i| i['displayName'] == 'RV1 - Reserve Records Request' }&.each do |i|
        i['status'] = 'NEEDED_FROM_OTHERS'
      end
      claim
    end

    def suppress_evidence_requests(claim)
      tracked_items = claim.dig('data', 'attributes', 'trackedItems')
      return unless tracked_items

      tracked_items.reject! { |i| BenefitsClaims::Constants::SUPPRESSED_EVIDENCE_REQUESTS.include?(i['displayName']) }
      claim
    end

    def report_evidence_submission_metrics(endpoint, evidence_submissions)
      status_counts = evidence_submissions.group(:upload_status).count

      BenefitsDocuments::Constants::UPLOAD_STATUS.each_value do |status|
        count = status_counts[status] || 0
        next if count.zero?

        StatsD.increment("#{STATSD_METRIC_PREFIX}.#{endpoint}", count, tags: STATSD_TAGS + ["status:#{status}"])
      end
    rescue => e
      ::Rails.logger.error(
        "BenefitsClaimsController##{endpoint} Error reporting evidence submission upload status metrics: #{e.message}"
      )
    end

    def fetch_evidence_submissions(claim_ids, endpoint)
      EvidenceSubmission.where(claim_id: claim_ids)
    rescue => e
      ::Rails.logger.error(
        "BenefitsClaimsController##{endpoint} Error fetching evidence submissions",
        {
          claim_ids: Array(claim_ids),
          error_message: e.message,
          error_class: e.class.name,
          timestamp: Time.now.utc
        }
      )
      EvidenceSubmission.none
    end

    def update_evidence_submissions_for_claim(claim_id, evidence_submissions)
      # Poll for updated statuses on pending evidence submissions if feature flag is enabled
      if Flipper.enabled?(:cst_update_evidence_submission_on_show, @current_user)
        # Get pending evidence submissions as an ActiveRecord relation
        # PENDING = successfully sent to Lighthouse with request_id, awaiting final status
        # Note: We chain scopes on the provided relation because UpdateDocumentsStatusService
        # requires an ActiveRecord::Relation with find_by! method (not an Array)
        pending_submissions = evidence_submissions.where(
          upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING]
        ).where.not(request_id: nil)

        unless pending_submissions.empty?
          request_ids = pending_submissions.pluck(:request_id)

          # Check if we recently polled for the same request_ids (cache hit)
          if recently_polled_request_ids?(claim_id, request_ids)
            StatsD.increment("#{STATSD_METRIC_PREFIX}.show.evidence_submission_cache_hit", tags: STATSD_TAGS)
            return
          end

          # Cache miss - proceed with polling
          StatsD.increment("#{STATSD_METRIC_PREFIX}.show.evidence_submission_cache_miss", tags: STATSD_TAGS)
          process_evidence_submissions(claim_id, pending_submissions, request_ids)
        end
      end
    end

    def process_evidence_submissions(claim_id, pending_submissions, request_ids)
      poll_response = poll_lighthouse_for_status(claim_id, request_ids)
      return unless poll_response

      process_status_update(claim_id, pending_submissions, poll_response, request_ids)
    end

    def poll_lighthouse_for_status(claim_id, request_ids)
      # Call the same polling service used by the hourly job
      poll_response = BenefitsDocuments::DocumentsStatusPollingService.call(request_ids)

      # Validate successful response with expected data structure
      if poll_response.status == 200
        if poll_response.body&.dig('data', 'statuses').blank?
          # Handle case where Lighthouse response doesn't have statuses
          error_response = OpenStruct.new(status: 200, body: poll_response.body)
          handle_error(claim_id, error_response, request_ids, 'polling')
          return nil
        end

        poll_response
      else
        # Log non-200 responses
        handle_error(claim_id, poll_response, request_ids, 'polling')
      end
    rescue => e
      # Catch unexpected exceptions from polling service (network errors, timeouts, etc.)
      error_response = OpenStruct.new(status: nil, body: e.message)
      handle_error(claim_id, error_response, request_ids, 'polling')
    end

    def process_status_update(claim_id, pending_submissions, poll_response, request_ids)
      update_result = BenefitsDocuments::UpdateDocumentsStatusService.call(
        pending_submissions,
        poll_response.body
      )

      # Handle case where update service found unknown request IDs
      if update_result && !update_result[:success]
        response_struct = OpenStruct.new(update_result[:response])
        handle_error(claim_id, response_struct, response_struct.unknown_ids.map(&:to_s), 'update')
      else
        # Log success metric when polling and update complete successfully
        StatsD.increment("#{STATSD_METRIC_PREFIX}.show.upload_status_success", tags: STATSD_TAGS)
        # Cache the polled request_ids to prevent redundant polling within TTL window
        cache_polled_request_ids(claim_id, request_ids)
      end
    rescue => e
      # Catch unexpected exceptions from update operations
      # Log error but don't fail the request - graceful degradation
      error_response = OpenStruct.new(status: 200, body: e.message)
      handle_error(claim_id, error_response, request_ids, 'update')
    end

    def handle_error(claim_id, response, lighthouse_document_request_ids, error_source)
      ::Rails.logger.error(
        'BenefitsClaimsController#show Error polling evidence submissions',
        {
          claim_id:,
          error_source:,
          response_status: response.status,
          response_body: response.body,
          lighthouse_document_request_ids:,
          timestamp: Time.now.utc
        }
      )
      StatsD.increment(
        "#{STATSD_METRIC_PREFIX}.show.upload_status_error",
        tags: STATSD_TAGS + ["error_source:#{error_source}"]
      )
    end

    def add_evidence_submissions_to_claims(claims, all_evidence_submissions, endpoint)
      return if claims.empty?

      # Group evidence submissions by claim_id for efficient lookup
      evidence_submissions_by_claim = all_evidence_submissions.group_by(&:claim_id)

      # Add evidence submissions to each claim
      claims.each do |claim|
        claim_id = claim['id'].to_i
        evidence_submissions = evidence_submissions_by_claim[claim_id] || []

        claim['attributes']['evidenceSubmissions'] =
          add_evidence_submissions(claim, evidence_submissions)
      end
    rescue => e
      # Log error but don't fail the request - graceful degradation
      # Frontend already handles missing evidenceSubmissions attribute
      claim_ids = claims.map { |claim| claim['id'] }
      ::Rails.logger.error(
        "BenefitsClaimsController##{endpoint} Error adding evidence submissions",
        {
          claim_ids:,
          error_class: e.class.name
        }
      )
    end

    def recently_polled_request_ids?(claim_id, request_ids)
      cache_record = EvidenceSubmissionPollStore.find(claim_id.to_s)
      return false if cache_record.nil?

      cache_record.request_ids.sort == request_ids.sort
    rescue => e
      ::Rails.logger.error(
        'BenefitsClaimsController#show Error reading evidence submission poll cache',
        {
          claim_id:,
          request_ids:,
          error_class: e.class.name,
          error_message: e.message
        }
      )
      false
    end

    def cache_polled_request_ids(claim_id, request_ids)
      EvidenceSubmissionPollStore.create(
        claim_id: claim_id.to_s,
        request_ids:
      )
    rescue => e
      ::Rails.logger.error(
        'BenefitsClaimsController#show Error writing evidence submission poll cache',
        {
          claim_id:,
          request_ids:,
          error_class: e.class.name,
          error_message: e.message
        }
      )
    end
  end
end
