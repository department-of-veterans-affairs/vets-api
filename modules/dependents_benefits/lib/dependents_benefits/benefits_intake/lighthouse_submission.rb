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
      FOREIGN_POSTALCODE = '00000'

      attr_reader :saved_claim, :user_data, :proc_id, :lighthouse_service

      def initialize(saved_claim, user_data, proc_id = nil)
        @saved_claim = saved_claim
        @user_data = user_data
        @proc_id = proc_id
        # Set a default empty array for attachment_paths to avoid nil errors in cleanup_file_paths
        @attachment_paths = []
      end

      def initialize_service
        @lighthouse_service = BenefitsIntakeService::Service.new(with_upload_location: true)
        @uuid = lighthouse_service.uuid
      end

      def prepare_submission
        saved_claim.add_veteran_info(user_data)
        get_files_from_claim
      end

      def upload_to_lh
        lighthouse_service.upload_form(
          main_document: split_file_and_path(form_path),
          attachments: attachment_paths.map(&method(:split_file_and_path)),
          form_metadata: generate_metadata_lh
        )
      end

      def cleanup_file_paths
        Common::FileHelpers.delete_file_if_exists(form_path)
        attachment_paths.each { |p| Common::FileHelpers.delete_file_if_exists(p) }
      end

      private

      def get_files_from_claim
        # process the main pdf record and the attachments as we would for a vbms submission
        form_674_paths = []
        form_686c_path = nil
        DependentsBenefits::ClaimProcessor.new(saved_claim.id, proc_id).collect_child_claims.each do |claim|
          pdf_path = process_pdf(claim.to_pdf, claim.created_at, claim.form_id)

          if claim.form_id == DependentsBenefits::ADD_REMOVE_DEPENDENT
            form_686c_path = pdf_path
          else
            form_674_paths << pdf_path
          end
        end

        # set main form_path to be first 674 in array if needed
        @form_path = form_686c_path.presence || form_674_paths.shift

        # prepend any 674s to attachments
        @attachment_paths = form_674_paths + saved_claim.persistent_attachments.map do |pa|
          process_pdf(pa.to_pdf, saved_claim.created_at)
        end
      end

      def process_pdf(pdf_path, timestamp = nil, form_id = nil)
        stamped_path1 = PDFUtilities::DatestampPdf.new(pdf_path).run(
          text: 'VA.GOV', x: 5, y: 5, timestamp:, template: "#{DependentsBenefits::PDF_PATH_BASE}/#{form_id}.pdf"
        )
        stamped_path2 = PDFUtilities::DatestampPdf.new(stamped_path1).run(
          text: 'FDC Reviewed - va.gov Submission', x: 400, y: 770, text_only: true, template: "#{DependentsBenefits::PDF_PATH_BASE}/#{form_id}.pdf"
        )
        if form_id.present?
          stamped_pdf_with_form(form_id, stamped_path2, timestamp)
        else
          stamped_path2
        end
      end

      def get_hash_and_pages(file_path)
        {
          hash: Digest::SHA256.file(file_path).hexdigest,
          pages: PdfInfo::Metadata.read(file_path).pages
        }
      end

      def user_zipcode
        address = saved_claim.parsed_form.dig('dependents_application', 'veteran_contact_information',
                                              'veteran_address')
        address['country_name'] == 'USA' ? address['postal_code'] : FOREIGN_POSTALCODE
      end

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

      def stamped_pdf_with_form(form_id, path, timestamp)
        PDFUtilities::DatestampPdf.new(path).run(
          text: 'Application Submitted on va.gov',
          x: 400,
          y: 675,
          text_only: true, # passing as text only because we override how the date is stamped in this instance
          timestamp:,
          page_number: %w[686C-674 686C-674-V2].include?(form_id) ? 6 : 0,
          template: "#{DependentsBenefits::PDF_PATH_BASE}/#{form_id}.pdf",
          multistamp: true
        )
      end

      def split_file_and_path(path) = { file: path, file_name: path.split('/').last }

      def form_path = @form_path || nil

      def uuid = @uuid || nil
    end
  end
end
