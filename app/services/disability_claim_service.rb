# frozen_string_literal: true
require_dependency 'evss/claims_service'
require_dependency 'evss/documents_service'
require_dependency 'evss/auth_headers'

class DisabilityClaimService
  EVSS_CLAIM_KEYS = %w(openClaims historicalClaims).freeze

  def initialize(user)
    @user = user
  end

  def all
    raw_claims = client.all_claims.body
    EVSS_CLAIM_KEYS.each_with_object([]) do |key, claims|
      next unless raw_claims[key]
      claims << raw_claims[key].map do |raw_claim|
        create_or_update_claim(raw_claim)
      end.compact
    end.flatten
  rescue Faraday::Error::TimeoutError, Breakers::OutageException => e
    log_error(e)
    claims_scope.all.map do |claim|
      claim.successful_sync = false
      claim
    end
  end

  def update_from_remote(claim)
    begin
      raw_claim = client.find_claim_by_id(claim.evss_id).body.fetch('claim', {})
      claim.update_attributes(data: raw_claim, successful_sync: true)
    rescue Faraday::Error::TimeoutError, Breakers::OutageException => e
      claim.successful_sync = false
      log_error(e)
    end
    claim
  end

  def request_decision(claim)
    client.submit_5103_waiver(claim.evss_id).body
  end

  # upload file to s3 and enqueue job to upload to EVSS
  def upload_document(claim, tempfile, tracked_item_id)
    uploader = DisabilityClaimDocumentUploader.new(@user.uuid, tracked_item_id)
    uploader.store!(tempfile)
    DisabilityClaim::DocumentUpload.perform_later(tempfile.original_filename,
                                                  auth_headers, @user.uuid,
                                                  claim.id, tracked_item_id)
  end

  private

  def client
    @client ||= EVSS::ClaimsService.new(auth_headers)
  end

  def document_client
    @document_client ||= EVSS::DocumentsService.new(auth_headers)
  end

  def auth_headers
    @auth_headers ||= EVSS::AuthHeaders.new(@user).to_h
  end

  def claims_scope
    DisabilityClaim.for_user(@user)
  end

  DISABILITY_BENEFIT_CODES = %w(
    010DICI 010DICP 010EPDMR8 010EXPDMR8 010INITMORE8 010IPDD2D
    010IPDSEP 010LCOMP 010LCOMPBDD 010LCOMPD2D 010LCOMPP 010LCOMPPRD
    010LCOMPSEP 010PD 010PDFDC 010PREDMORE8 010QP 011IPDD2D 017IPDD2D
    020CLMINC 020CPHLP 020DS 020DSI 020EPDSUPP 020EXPD 020INCMPRVSC
    020NEW 020NEWBDD 020NHPNH10 020NI 020NR 20NRI 020PD 020PDD2D
    020PDFDC 020PDSEP 020PREDSUPP 020QP 020RCOMP 020RI 020RN 020SCOMPBDD
    020SCOMPPRD 020SD2D 020SMB 020SSEP 020SUPP 20WCP 021PDD2D 025NA
    025NHP 025NR 110DILCI 110DLCP 110EPDLS8 110EXPDLS8 110INITLESS8
    110LCOMP 110LCOMP7 110LCOMP7BDD 110LCOMP7PRD 110LCOMPD2D 110LCOMPSEP
    110PD 110PDFDC 110PDID2D 110PDISEP 110PREDLESS8 110QP 110WCP
    111PDID2D 117PDID2D 400EPDLS8 400EPDMR8 400EPDSUPP 400EXPDLS8
    400EXPDMR8 400EXPDSUPP 400ILCOMPD2D 400ILCOMPSEP 400INITLESS8
    400INITMORE8 400LCOMPD2D 400LCOMPSEP 400PDD2D 400PDSEP 400PREDSCHRG
    400SD2D 400SSEP 400SUPP 930RC 930RVWRF
  ).to_set.freeze

  def create_or_update_claim(raw_claim)
    # Only save claim if its benefitClaimTypeCode is for a disability claim
    return nil unless DISABILITY_BENEFIT_CODES.include? raw_claim['benefitClaimTypeCode']
    claim = claims_scope.where(evss_id: raw_claim['id']).first_or_initialize(data: {})
    claim.update_attributes(data: claim.data.merge(raw_claim), successful_sync: true)
    claim
  end

  def log_error(exception)
    Rails.logger.error "#{exception.message}."
    Rails.logger.error exception.backtrace.join("\n") unless exception.backtrace.nil?
  end
end
