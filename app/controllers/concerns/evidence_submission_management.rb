# frozen_string_literal: true

module EvidenceSubmissionManagement
  extend ActiveSupport::Concern

  STATSD_METRIC_PREFIX = 'api.benefits_claims'
  STATSD_TAGS = [
    'service:benefits-claims',
    'team:cross-benefits-crew',
    'team:benefits',
    'itportfolio:benefits-delivery',
    'dependency:lighthouse'
  ].freeze

  def safely_add_evidence_submissions(claims, evidence_submissions, endpoint, claim_ids)
    add_evidence_submissions_to_claims(claims, evidence_submissions, endpoint)
  rescue => e
    ::Rails.logger.error(
      "BenefitsClaimsController##{endpoint} Error adding evidence submissions",
      { claim_ids:, error_class: e.class.name }
    )
  end

  def add_evidence_submissions_to_claims(claims, all_evidence_submissions, endpoint)
    return if claims.empty?

    evidence_submissions_by_claim = all_evidence_submissions.group_by(&:claim_id)
    claims.each do |claim|
      claim_id = claim['id'].to_i
      evidence_submissions = evidence_submissions_by_claim[claim_id] || []
      non_duplicate_submissions = filter_duplicate_evidence_submissions(evidence_submissions, claim)
      tracked_items = claim['attributes']['trackedItems']
      claim['attributes']['evidenceSubmissions'] =
        non_duplicate_submissions.map { |es| build_filtered_evidence_submission_record(es, tracked_items) }
    end
  rescue => e
    ::Rails.logger.error(
      "BenefitsClaimsController##{endpoint} Error adding evidence submissions",
      { claim_ids: claims.map { |claim| claim['id'] }, error_class: e.class.name }
    )
  end

  def filter_duplicate_evidence_submissions(evidence_submissions, claim)
    supporting_documents = claim['attributes']['supportingDocuments'] || []
    received_file_names = supporting_documents.map { |doc| doc['originalFileName'] }.compact
    return evidence_submissions if received_file_names.empty?

    evidence_submissions.reject do |es|
      file_name = extract_evidence_submission_file_name(es)
      file_name && received_file_names.include?(file_name)
    end
  end

  def extract_evidence_submission_file_name(evidence_submission)
    return nil if evidence_submission.template_metadata.nil?

    metadata = JSON.parse(evidence_submission.template_metadata)
    personalisation = metadata['personalisation']
    personalisation.is_a?(Hash) ? personalisation['file_name'] : nil
  rescue JSON::ParserError, TypeError
    ::Rails.logger.error(
      '[BenefitsClaimsController] Error parsing evidence submission metadata',
      { evidence_submission_id: evidence_submission.id }
    )
    nil
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
      { claim_ids: Array(claim_ids), error_message: e.message, error_class: e.class.name, timestamp: Time.now.utc }
    )
    EvidenceSubmission.none
  end
end
