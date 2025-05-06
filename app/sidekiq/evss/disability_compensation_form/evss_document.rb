# frozen_string_literal: true

require 'pdf_utilities/datestamp_pdf'
require 'pdf_fill/filler'

module EVSS
  module DisabilityCompensationForm
    # Base document class for the 526 ancillary forms
    #
    # @!attribute pdf_path [String] The file path of the PDF
    #
    class EVSSDocument
      # @return [String] the contents of the file
      #
      def file_body
        File.read(@pdf_path)
      end

      # @return [EVSSClaimDocument] A new claim document instance
      #
      def data
        @document_data
      end

      attr_reader :pdf_path

      private

      # Invokes Filler ancillary form method to generate PDF document
      # Then calls method PDFUtilities::DatestampPdf to stamp the document.
      # Its called twice, once to stamp with text "VA.gov YYYY-MM-DD" at the bottom of each page
      # and second time to stamp with text "VA.gov Submission" at the top of each page
      def generate_stamp_pdf(form_content, submitted_claim_id, form_id)
        pdf_path = PdfFill::Filler.fill_ancillary_form(form_content, submitted_claim_id, form_id)
        stamped_path1 = PDFUtilities::DatestampPdf.new(pdf_path).run(text: 'VA.gov', x: 5, y: 5)
        PDFUtilities::DatestampPdf.new(stamped_path1).run(
          text: 'VA.gov Submission',
          x: 510,
          y: 775,
          text_only: true
        )
      end

      def get_evss_claim_metadata(pdf_path, doc_type)
        pdf_path_split = pdf_path.split('/')
        {
          doc_type:,
          file_name: pdf_path_split.last
        }
      end

      def create_document_data(evss_claim_id, upload_data, doc_type)
        EVSSClaimDocument.new(
          evss_claim_id:,
          file_name: upload_data[:file_name],
          tracked_item_id: nil,
          document_type: doc_type
        )
      end
    end
  end
end
