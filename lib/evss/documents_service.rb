# frozen_string_literal: true
require 'common/exceptions'
require_dependency 'evss/base_service'

module EVSS
  # DocumentData is a struct class bundling together the required attributes of a file upload
  DocumentData = Struct.new(
    :evss_claim_id, :tracked_item_id, :document_type, :description, :file_name
  ) do
    # rubocop:disable LineLength
    DOCUMENT_TYPES = {
      'L029' => 'Copy of a DD214',
      'L450' => 'STR - Dental - Photocopy',
      'L451' => 'STR - Medical - Photocopy',
      'L049' => 'Medical Treatment Record - Non-Government Facility',
      'L034' => 'Military Personnel Record',
      'L107' => 'VA Form 21-4142 - Authorization To Disclose Information',
      'L827' => 'VA Form 21-4142a - General Release for Medical Provider Information',
      'L229' => 'VA Form 21-0781a - Statement in Support of Claim for PTSD Secondary to Personal Assault',
      'L228' => 'VA Form 21-0781 - Statement in Support of Claim for PTSD',
      'L149' => 'VA Form 21-8940 - Veterans Application for Increased Compensation Based on Un-employability',
      'L115' => 'VA Form 21-4192 - Request for Employment Information in Connection with Claim for Disability',
      'L159' => 'VA Form 26-4555 - Application in Acquiring Specially Adapted Housing or Special Home Adaptation Grant',
      'L117' => 'VA Form 21-4502 - Application for Automobile or Other Conveyance and Adaptive Equipment Under 38 U.S.C. 3901-3904',
      'L139' => 'VA Form 21-686c - Declaration of Status of Dependents',
      'L133' => 'VA Form 21-674 - Request for Approval of School Attendance',
      'L102' => 'VA Form 21-2680 - Examination for Housebound Status or Permanent Need for Regular Aid & Attendance',
      'L222' => 'VA Form 21-0779 - Request for Nursing Home Information in Connection with Claim for Aid & Attendance',
      'L702' => 'Disability Benefits Questionnaire (DBQ)',
      'L703' => 'Goldmann Perimetry Chart/Field Of Vision Chart',
      'L070' => 'Photographs',
      'L023' => 'Other Correspondence'
    }.freeze

    def validate!
      description = DOCUMENT_TYPES[document_type]
      raise Common::Exceptions::InvalidFieldValue.new('document_type', document_type) unless description
      self
    end
  end

  class DocumentsService < BaseService
    BASE_URL = "#{ENV['EVSS_BASE_URL']}/wss-document-services-web-3.0/rest/"

    def all_documents
      get 'documents/getAllDocuments'
    end

    def upload(file_body, document_data)
      headers = { 'Content-Type' => 'application/octet-stream' }
      post 'queuedDocumentUploadService/ajaxUploadFile', file_body, headers do |req|
        req.params['systemName'] = SYSTEM_NAME
        req.params['docType'] = document_data.document_type
        req.params['docTypeDescription'] = document_data.description
        req.params['claimId'] = document_data.evss_claim_id
        # In theory one document can correspond to multiple tracked items
        # To do that, add multiple query parameters
        req.params['trackedItemIds'] = document_data.tracked_item_id
        req.params['qqfile'] = document_data.file_name
      end
    end

    def self.breakers_service
      BaseService.create_breakers_service(name: 'EVSS/Documents', url: BASE_URL)
    end
  end
end
