# frozen_string_literal: true

module AccreditedRepresentativePortal
  module Form21aDocumentUploadConstants
    # File type codes expected by GCLAWS Document API
    FILE_TYPES = {
      'application/pdf' => 1,
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => 2
    }.freeze

    # Maps form_data document keys to GCLAWS document type codes.
    # The keys are derived from details_slug: "conviction-details" -> "convictionDetailsDocuments"
    #
    # WARNING: These are placeholder sequential values (1-14).
    # TODO: Confirm these document type codes match the GCLAWS API spec before production use.
    DOCUMENT_TYPES = {
      'convictionDetailsDocuments' => 1,
      'courtMartialedDetailsDocuments' => 2,
      'underChargesDetailsDocuments' => 3,
      'resignedFromEducationDetailsDocuments' => 4,
      'withdrawnFromEducationDetailsDocuments' => 5,
      'disciplinedForDishonestyDetailsDocuments' => 6,
      'resignedForDishonestyDetailsDocuments' => 7,
      'representativeForAgencyDetailsDocuments' => 8,
      'reprimandedInAgencyDetailsDocuments' => 9,
      'resignedFromAgencyDetailsDocuments' => 10,
      'appliedForVaAccreditationDetailsDocuments' => 11,
      'terminatedByVsorgDetailsDocuments' => 12,
      'conditionThatAffectsRepresentationDetailsDocuments' => 13,
      'conditionThatAffectsExaminationDetailsDocuments' => 14
    }.freeze

    # Returns the GCLAWS file type code for a given content type
    # @param content_type [String] MIME type (e.g., "application/pdf")
    # @return [Integer, nil] GCLAWS file type code (1=PDF, 2=DOCX) or nil if unknown
    def self.file_type_for(content_type)
      FILE_TYPES[content_type]
    end

    # Returns the GCLAWS document type code for a given form_data key
    # @param documents_key [String] The key from form_data (e.g., "convictionDetailsDocuments")
    # @return [Integer, nil] GCLAWS document type code or nil if unknown
    def self.document_type_for(documents_key)
      DOCUMENT_TYPES[documents_key]
    end
  end
end
