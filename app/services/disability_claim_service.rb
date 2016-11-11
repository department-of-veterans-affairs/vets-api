# frozen_string_literal: true
require 'evss/claims_service'
require 'evss/documents_service'
require 'evss/auth_headers'

class DisabilityClaimService
  EVSS_CLAIM_KEYS = %w(openClaims historicalClaims).freeze

  # Codes for claim types that are disability claims. See
  # https://github.com/department-of-veterans-affairs/sunsets-team/blob/master/track-claim-status/technical/Dis_Clm_types.md
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

  def initialize(user)
    @user = user
  end

  def all
    raw_claims = client.all_claims.body
    claims = EVSS_CLAIM_KEYS.each_with_object([]) do |key, claim_accum|
      next unless raw_claims[key]
      disability_claims = raw_claims[key].select do |raw_claim|
        DISABILITY_BENEFIT_CODES.include? raw_claim['benefitClaimTypeCode']
      end
      claim_accum << disability_claims.map do |raw_claim|
        create_or_update_claim(raw_claim)
      end
    end.flatten
    return claims, true
  rescue Faraday::Error::TimeoutError, Breakers::OutageException => e
    log_error(e)
    return claims_scope.all, false
  end

  def update_from_remote(claim)
    begin
      raw_claim = client.find_claim_by_id(claim.evss_id).body.fetch('claim', {})
      claim.update_attributes(data: raw_claim)
      successful_sync = true
    rescue Faraday::Error::TimeoutError, Breakers::OutageException => e
      log_error(e)
      successful_sync = false
    end
    [claim, successful_sync]
  end

  def request_decision(claim)
    DisabilityClaim::RequestDecision.perform_async(auth_headers, claim.evss_id)
  end

  # upload file to s3 and enqueue job to upload to EVSS
  def upload_document(file, disability_claim_document)
    uploader = DisabilityClaimDocumentUploader.new(@user.uuid, disability_claim_document.tracked_item_id)
    uploader.store!(file)
    # the uploader sanitizes the filename before storing, so set our doc to match
    # TODO: set this directly on the model, need to modify common/model/base to update attributes hash
    disability_claim_document.attributes[:file_name] = uploader.filename
    DisabilityClaim::DocumentUpload.perform_async(auth_headers, @user.uuid, disability_claim_document.to_h)
  end

  private

  def client
    @client ||= EVSS::ClaimsService.new(auth_headers)
  end

  def auth_headers
    @auth_headers ||= EVSS::AuthHeaders.new(@user).to_h
  end

  def claims_scope
    DisabilityClaim.for_user(@user)
  end

  def create_or_update_claim(raw_claim)
    claim = claims_scope.where(evss_id: raw_claim['id']).first_or_initialize(data: {})
    claim.update_attributes(list_data: raw_claim)
    claim
  end

  def log_error(exception)
    Rails.logger.error "#{exception.message}."
    Rails.logger.error exception.backtrace.join("\n") unless exception.backtrace.nil?
  end
end
