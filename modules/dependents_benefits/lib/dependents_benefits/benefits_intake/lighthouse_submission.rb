# frozen_string_literal: true

# require 'central_mail/service'
# require 'benefits_intake_service/service'
# require 'pdf_utilities/datestamp_pdf'
# require 'pdf_info'
# require 'simple_forms_api_submission/metadata_validator'

module DependentsBenefits
  module BenefitsIntake
    ##
    # Handles submission of dependent claims to Lighthouse as a backup service
    #
    class LighthouseSubmission
      # Postal code used for foreign addresses
      FOREIGN_POSTALCODE = '00000'

      attr_reader :saved_claim, :user_data, :proc_id, :lighthouse_service, :attachment_paths, :form_path, :uuid

      # Initializes a new LighthouseSubmission instance
      #
      # @param saved_claim [SavedClaim::DependencyClaim] The saved dependency claim to submit
      # @param user_data [Hash] Hash containing veteran information and user details
      # @param proc_id [String, nil] Optional processor ID for tracking the submission
      # @return [LighthouseSubmission] A new instance of LighthouseSubmission
      def initialize(saved_claim, user_data, proc_id = nil)
        @saved_claim = saved_claim
        @user_data = user_data
        @proc_id = proc_id
        # Set a default empty array for attachment_paths to avoid nil errors in cleanup_file_paths
        @attachment_paths = []
        @form_path = nil
        @uuid = nil
      end

      # Initializes the Lighthouse Benefits Intake Service
      #
      # Creates a new BenefitsIntakeService instance with upload location enabled and
      # sets the UUID for tracking the submission
      #
      # @return [void]
      def initialize_service
        @lighthouse_service = BenefitsIntakeService::Service.new(with_upload_location: true)
        @uuid = lighthouse_service.uuid
      end

      # Prepares the submission by adding veteran information and collecting files
      #
      # This method adds veteran information to the saved claim and collects all
      # necessary form PDFs and attachments for submission
      #
      # @return [void]
      def prepare_submission
        saved_claim.add_veteran_info(user_data)
        get_files_from_claim
      end

      # Uploads the form and attachments to Lighthouse Benefits Intake
      #
      # Submits the main form PDF and all attachments to the Lighthouse Benefits Intake
      # service along with the generated metadata
      #
      # @return [Hash] Response from the Lighthouse Benefits Intake service
      def upload_to_lh
        lighthouse_service.upload_form(
          main_document: split_file_and_path(form_path),
          attachments: attachment_paths.map(&method(:split_file_and_path)),
          form_metadata: generate_metadata_lh
        )
      end

      # Cleans up temporary PDF files after submission
      #
      # Deletes the main form PDF and all attachment PDFs that were generated
      # for the submission
      #
      # @return [void]
      def cleanup_file_paths
        Common::FileHelpers.delete_file_if_exists(form_path)
        attachment_paths.each { |p| Common::FileHelpers.delete_file_if_exists(p) }
      end

      # Processes and stamps a PDF with submission information
      #
      # Applies multiple stamps to the PDF including VA.GOV branding, FDC review notice,
      # and optional form-specific submission date stamp
      #
      # @param pdf_path [String] Path to the PDF file to process
      # @param timestamp [Time, nil] Optional timestamp for the submission date stamp
      # @param form_id [String, nil] Optional form ID to determine specific stamping behavior
      # @return [String] Path to the final stamped PDF file
      def process_pdf(pdf_path, timestamp = nil, form_id = nil)
        template = template_for_form(form_id)
        stamped_path1 = PDFUtilities::DatestampPdf.new(pdf_path).run(
          text: 'VA.GOV', x: 5, y: 5, timestamp:, template:
        )
        stamped_path2 = PDFUtilities::DatestampPdf.new(stamped_path1).run(
          text: 'FDC Reviewed - va.gov Submission', x: 400, y: 770, text_only: true, template:
        )
        if form_id.present?
          stamped_pdf_with_form(form_id, stamped_path2, timestamp)
        else
          stamped_path2
        end
      end

      private

      # Collects and processes all PDF files from the claim
      #
      # Processes the main form (686C) and any supporting forms (674) along with
      # attachments. Sets the main form path and attachment paths for submission.
      # Form 686C takes priority as the main form, otherwise the first 674 is used.
      #
      # @raise [RuntimeError] if no main form PDF is generated
      # @return [void]
      def get_files_from_claim
        # process the main pdf record and the attachments as we would for a vbms submission
        form_674_paths = []
        form_686c_path = nil
        DependentsBenefits::ClaimProcessor.new(saved_claim.id).collect_child_claims.each do |claim|
          # NOTE: potentially move to initialization of claims
          claim.add_veteran_info(user_data)
          pdf_path = process_pdf(claim.to_pdf, claim.created_at, claim.form_id)

          if claim.form_id == DependentsBenefits::ADD_REMOVE_DEPENDENT
            form_686c_path = pdf_path
          else
            form_674_paths << pdf_path
          end
        end

        # set main form_path to be first 674 in array if needed
        @form_path = form_686c_path.presence || form_674_paths.shift

        raise 'No main form PDF generated for Lighthouse submission' if form_path.blank?

        # prepend any 674s to attachments
        @attachment_paths = form_674_paths + saved_claim.persistent_attachments.map do |pa|
          process_pdf(pa.to_pdf, saved_claim.created_at)
        end
      end

      # Generates hash and page count for a PDF file
      #
      # @param file_path [String] Path to the PDF file
      # @return [Hash] Hash containing :hash (SHA256 digest) and :pages (page count)
      def get_hash_and_pages(file_path)
        {
          hash: Digest::SHA256.file(file_path).hexdigest,
          pages: PdfInfo::Metadata.read(file_path).pages
        }
      end

      # Extracts the veteran's zip code from the claim
      #
      # Returns the veteran's postal code if they have a USA address with a valid
      # postal code, otherwise returns the foreign postal code constant (00000)
      #
      # @return [String] The veteran's zip code or FOREIGN_POSTALCODE
      def user_zipcode
        address = saved_claim.parsed_form.dig('dependents_application', 'veteran_contact_information',
                                              'veteran_address')
        if address.present? && address['country_name'] == 'USA' && address['postal_code'].present?
          address['postal_code']
        else
          FOREIGN_POSTALCODE
        end
      end

      # Generates metadata for Lighthouse Benefits Intake submission
      #
      # Creates a metadata hash containing veteran information, claim details,
      # and submission source for the Lighthouse Benefits Intake API
      #
      # @return [Hash] Metadata hash with veteran information and claim details
      # @option return [String] :veteran_first_name Veteran's first name
      # @option return [String] :veteran_last_name Veteran's last name
      # @option return [String] :file_number Veteran's VA file number
      # @option return [String] :zip Veteran's zip code
      # @option return [String] :doc_type Form ID of the claim
      # @option return [Time] :claim_date Date the claim was created
      # @option return [String] :source Submission source identifier
      # @option return [String] :business_line Business line code (CMP)
      def generate_metadata_lh
        veteran_information = user_data['veteran_information']
        {
          veteran_first_name: veteran_information['full_name']['first'],
          veteran_last_name: veteran_information['full_name']['last'],
          file_number: veteran_information['va_file_number'],
          zip: user_zipcode,
          doc_type: saved_claim.form_id,
          claim_date: saved_claim.created_at,
          source: 'va.gov backup dependent claim submission',
          business_line: 'CMP'
        }
      end

      # Stamps a PDF with form-specific submission information
      #
      # Adds a submission date stamp to the PDF with form-specific positioning.
      # For combined 686C-674 forms, stamps on page 6; otherwise stamps on page 0.
      #
      # @param form_id [String] The form identifier (e.g., '686C-674', '686C-674-V2')
      # @param path [String] Path to the PDF file to stamp
      # @param timestamp [Time] The submission timestamp
      # @return [String] Path to the stamped PDF file
      def stamped_pdf_with_form(form_id, path, timestamp)
        PDFUtilities::DatestampPdf.new(path).run(
          text: 'Application Submitted on va.gov',
          x: 400,
          y: 675,
          text_only: true, # passing as text only because we override how the date is stamped in this instance
          timestamp:,
          page_number: %w[686C-674 686C-674-V2].include?(form_id) ? 6 : 0,
          template: template_for_form(form_id),
          multistamp: true
        )
      end

      # Returns the PDF template path for a given form ID
      #
      # @param form_id [String, nil] The form identifier
      # @return [String] The file path to the PDF template
      def template_for_form(form_id)
        form_id ? "#{DependentsBenefits::PDF_PATH_BASE}/#{form_id}.pdf" : DependentsBenefits::PDF_PATH_21_686C
      end

      # Splits a file path into file and filename components
      #
      # @param path [String] The full file path
      # @return [Hash] Hash containing :file (full path) and :file_name (basename)
      def split_file_and_path(path) = { file: path, file_name: path.split('/').last }
    end
  end
end
