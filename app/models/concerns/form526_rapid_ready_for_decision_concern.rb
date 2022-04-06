# frozen_string_literal: true

module Form526RapidReadyForDecisionConcern
  extend ActiveSupport::Concern

  # @param metadata_hash [Hash] to be merged into form_json['rrd_metadata']
  def add_metadata(metadata_hash)
    new_form_json = JSON.parse(form_json)
    new_form_json['rrd_metadata'] ||= {}
    new_form_json['rrd_metadata'].deep_merge!(metadata_hash)

    update!(form_json: JSON.dump(new_form_json))
    invalidate_form_hash
    self
  end

  def rrd_status
    return :processed if rrd_claim_processed?

    return :pending_ep if form.dig('rrd_metadata', 'offramp_reason') == 'pending_ep'

    :insufficient_data
  end

  # Fetch all claims from EVSS
  # @return [Boolean] whether there are any open EP 020's
  def pending_eps?
    pending = open_claims.any? { |claim| claim['base_end_product_code'] == '020' }
    add_metadata(offramp_reason: 'pending_ep') if pending
    pending
  end

  private

  def open_claims
    all_claims = EVSS::ClaimsService.new(auth_headers).all_claims.body
    all_claims['open_claims']
  end

  # @return if this claim submission was processed and fast-tracked by RRD
  def rrd_claim_processed?
    form_json.include? RapidReadyForDecision::FastTrackPdfUploadManager::DOCUMENT_TITLE
  end
end
