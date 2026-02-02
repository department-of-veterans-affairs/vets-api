# frozen_string_literal: true

require 'datadog'
require 'ves_api/client'
require 'common/pdf_helpers'

# rubocop:disable Metrics/ClassLength
# Note: Disabling this rule is temporary, refactoring of this class is planned
module IvcChampva
  module V1
    class UploadsController < ApplicationController
      skip_after_action :set_csrf_header

      include ActionView::Helpers::NumberHelper

      FORM_NUMBER_MAP = {
        '10-10D' => 'vha_10_10d',
        '10-10D-EXTENDED' => 'vha_10_10d',
        '10-7959F-1' => 'vha_10_7959f_1',
        '10-7959F-2' => 'vha_10_7959f_2',
        '10-7959C' => 'vha_10_7959c',
        '10-7959A' => 'vha_10_7959a'
      }.freeze

      RETRY_ERROR_CONDITIONS = [
        'failed to generate',
        'no such file',
        'an error occurred while verifying stamp:',
        'unable to find file'
      ].freeze

      def submit(form_data = nil)
        Datadog::Tracing.trace('Start IVC File Submission') do
          form_id = get_form_id
          Datadog::Tracing.active_trace&.set_tag('form_id', form_id)
          # This allows us to call submit internally (for 10-10d/10-7959c merged
          # form) without messing with the shared param object across functions
          parsed_form_data = form_data || JSON.parse(params.to_json)

          validate_mpi_profiles(parsed_form_data, form_id)

          response = handle_file_uploads_wrapper(form_id, parsed_form_data)

          if @current_user && response[:status] == 200
            InProgressForm.form_for_user(params[:form_number], @current_user)&.destroy!
          end

          render json: response[:json], status: response[:status]
        end
      rescue => e
        Rails.logger.error "Error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render json: { error_message: "Error: #{e.message}" }, status: :internal_server_error
      end

      def validate_mpi_profiles(parsed_form_data, form_id)
        if Flipper.enabled?(:champva_mpi_validation, @current_user) && form_id == 'vha_10_10d'
          begin
            # Query MPI and log validation results for veteran and beneficiaries on 10-10D submissions
            IvcChampva::MPIService.new.validate_profiles(parsed_form_data)
          rescue => e
            Rails.logger.error "Error validating MPI profiles: #{e.message}"
          end
        end
      end

      # This method handles generating OHI forms for all appropriate applicants
      # when a user submits a 10-10d/10-7959c merged form.
      def submit_champva_app_merged
        parsed_form_data = JSON.parse(params.to_json)
        form_id = get_form_id
        apps = applicants_with_ohi(parsed_form_data['applicants'])

        apps.each do |app|
          # Generate OHI forms for each applicant. Creates one form per 2 policies
          # to handle overflow when applicant has more than 2 health insurance policies.
          ohi_forms = generate_ohi_form(app, parsed_form_data)
          ohi_forms.each do |f|
            ohi_path = fill_ohi_and_return_path(f)
            ohi_supporting_doc = create_custom_attachment(f, ohi_path, 'VA form 10-7959c')
            add_supporting_doc(parsed_form_data, ohi_supporting_doc)
            f.track_delegate_form(form_id) if f.respond_to?(:track_delegate_form)
          end
        end

        submit(parsed_form_data)
      rescue => e
        log_error_and_respond("Error submitting merged form: #{e.message}", e)
      end

      ##
      # Handles PEGA/S3 file uploads and VES submission
      #
      # @param [String] form_id The ID of the current form, e.g., 'vha_10_10d' (see FORM_NUMBER_MAP)
      # @param [Hash] parsed_form_data complete form submission data object
      #
      # @return [Hash] response from build_json
      def handle_file_uploads_wrapper(form_id, parsed_form_data)
        if Flipper.enabled?(:champva_send_to_ves, @current_user) && form_id == 'vha_10_10d'
          # first, prepare and validate the VES request
          ves_request = prepare_ves_request(parsed_form_data)

          # get file_paths and metadata so we can use the metadata to update the VES records
          file_paths, metadata = get_file_paths_and_metadata(parsed_form_data)

          # call handle_file_uploads with new signature
          statuses, error_messages = call_upload_form(form_id, file_paths, metadata)

          response = build_json(statuses, error_messages)

          if should_generate_ves_json?(form_id)
            # Remove the VES JSON file from disk after upload
            ves_json_file = file_paths.find { |path| path.end_with?('_ves.json') }
            FileUtils.rm_f(ves_json_file) if ves_json_file
          end

          # if the response is successful, submit the VES request
          submit_ves_request(ves_request, metadata) if response[:status] == 200

          response
        else
          statuses, error_messages = call_handle_file_uploads(form_id, parsed_form_data)

          build_json(statuses, error_messages)
        end
      end

      ##
      # Determines if VES JSON should be generated as a supporting document
      #
      # @param [String] form_id The ID of the current form
      # @return [Boolean] true if VES JSON should be generated
      def should_generate_ves_json?(form_id)
        # Get the legacy form ID to handle versioned forms (e.g., vha_10_10d_2027 -> vha_10_10d)
        legacy_form_id = IvcChampva::FormVersionManager.get_legacy_form_id(form_id)
        Flipper.enabled?(:champva_send_ves_to_pega, @current_user) && legacy_form_id == 'vha_10_10d'
      end

      ##
      # Generates VES JSON file and returns the file path
      #
      # @param [Object] form The form instance with proper UUID and form_id
      # @param [Hash] parsed_form_data complete form submission data object
      # @return [String] The path to the generated VES JSON file
      def generate_ves_json_file(form, parsed_form_data)
        # Generate VES data
        ves_data = IvcChampva::VesDataFormatter.format_for_request(parsed_form_data)

        # Create temporary JSON file using form.uuid (absolute path like PDF files)
        ves_file_path = Rails.root.join("tmp/#{form.uuid}_#{form.form_id}_ves.json").to_s
        File.write(ves_file_path, ves_data.to_json)

        Rails.logger.info "VES JSON file generated for form #{form.form_id}: #{ves_file_path}"
        ves_file_path
      rescue => e
        # Don't raise - we don't want VES JSON generation failure to break the entire submission
        Rails.logger.error "Error generating VES JSON file for form #{form.form_id}: #{e.message}"
        nil
      end

      # Prepares data for VES, raising an exception if this cannot be done
      # @param [Hash] parsed_form_data complete form submission data object
      # @return [IvcChampva::VesRequest, nil] the formatted request data
      def prepare_ves_request(parsed_form_data)
        # Format data for VES submission.  If this is unsuccessful an error will be thrown, do not proceed.
        ves_request = IvcChampva::VesDataFormatter.format_for_request(parsed_form_data)
        raise 'Failed to format data for VES submission' if ves_request.nil?

        ves_request
      end

      # Submits data to VES while ignoring any errors that occur
      #
      # @param [IvcChampva::VesRequest, nil] ves_request the formatted request data
      # @param [Hash] metadata the metadata for the form
      def submit_ves_request(ves_request, metadata) # rubocop:disable Metrics/MethodLength
        unless ves_request.nil?
          ves_client = IvcChampva::VesApi::Client.new
          on_failure = lambda { |e, attempt|
            Rails.logger.error "Ignoring error when submitting to VES (attempt #{attempt}): #{e.message}"
          }

          response = nil

          begin
            # omitting retry_on to always retry for now
            IvcChampva::Retry.do(1, on_failure:) do
              ves_request.transaction_uuid = SecureRandom.uuid
              response = ves_client.submit_1010d(ves_request.transaction_uuid, 'fake-user', ves_request)
            end

            begin
              update_ves_records(metadata['uuid'], ves_request.application_uuid, response, ves_request.to_json)
            rescue => e
              Rails.logger.error "Ignoring error updating VES records: #{e.message}"
            end
          rescue => e
            # Log but don't propagate the error so the form submission can still succeed
            Rails.logger.error "Error in VES submission: #{e.message}"
          end

          response
        end
      end

      def update_ves_records(form_uuid, application_uuid, ves_response, ves_request_data)
        # this should be unique
        persisted_forms = IvcChampvaForm.where(form_uuid:)

        # ves_response in the db is freeform text and hard to parse
        # so only put the response body in the db if the response is not 200
        ves_status = if ves_response.nil?
                       'internal_server_error'
                     else
                       ves_response.status == 200 ? 'ok' : ves_response.body
                     end

        persisted_forms.each do |form|
          form.update(
            application_uuid:,
            ves_status:,
            ves_request_data:
          )
        end
      end

      def call_handle_file_uploads(form_id, parsed_form_data)
        if Flipper.enabled?(:champva_retry_logic_refactor, @current_user)
          handle_file_uploads_with_refactored_retry(form_id, parsed_form_data)
        else
          handle_file_uploads(form_id, parsed_form_data)
        end
      end

      ##
      # Wrapper around handle_file_uploads that allows us to use the new retry logic
      # based on the feature flag
      def call_upload_form(form_id, file_paths, metadata)
        if Flipper.enabled?(:champva_retry_logic_refactor, @current_user)
          upload_form_with_refactored_retry(form_id, file_paths, metadata)
        else
          upload_form(form_id, file_paths, metadata)
        end
      end

      # Modified from claim_documents_controller.rb:
      def unlock_file(file, file_password)
        return file unless File.extname(file) == '.pdf' && file_password

        tmpf = Tempfile.new(['decrypted_form_attachment', '.pdf'])

        tmpf = if Flipper.enabled?(:champva_use_hexapdf_to_unlock_pdfs, @current_user)
                 unlock_with_hexapdf(file, file_password, tmpf)
               else
                 unlock_with_pdftk(file, file_password, tmpf)
               end

        file.tempfile.unlink
        file.tempfile = tmpf
      end

      ## Uses pdftk to unlock the provided PDF file with the given password
      # @param [ActionDispatch::Http::UploadedFile] source_file The uploaded PDF file to unlock
      # @param [String] file_password The password to unlock the PDF
      # @param [Tempfile] destination_file A tempfile where the unlocked PDF will be saved
      def unlock_with_pdftk(source_file, file_password, destination_file)
        pdftk = PdfForms.new(Settings.binaries.pdftk)

        has_pdf_err = false
        begin
          pdftk.call_pdftk(source_file.tempfile.path, 'input_pw', file_password, 'output', destination_file.path)
        rescue PdfForms::PdftkError => e
          file_regex = %r{/(?:\w+/)*[\w-]+\.pdf\b}
          password_regex = /(input_pw).*?(output)/
          sanitized_message = e.message.gsub(file_regex, '[FILTERED FILENAME]').gsub(password_regex, '\1 [FILTERED] \2')
          Rails.logger.warn(sanitized_message)
          has_pdf_err = true
        end

        # This helps prevent leaking exception context to DataDog when we raise this error
        if has_pdf_err
          raise Common::Exceptions::UnprocessableEntity.new(
            detail: I18n.t('errors.messages.uploads.pdf.incorrect_password'),
            source: 'IvcChampva::V1::UploadsController'
          )
        end

        destination_file
      end

      ## Uses hexapdf to unlock the provided PDF file with the given password
      # @param [ActionDispatch::Http::UploadedFile] source_file The uploaded PDF file to unlock
      # @param [String] file_password The password to unlock the PDF
      # @param [Tempfile] destination_file A tempfile where the unlocked PDF will be saved
      def unlock_with_hexapdf(source_file, file_password, destination_file)
        has_pdf_err = false
        begin
          ::Common::PdfHelpers.unlock_pdf(source_file.tempfile.path, file_password, destination_file.path)
        rescue Common::Exceptions::UnprocessableEntity => e
          file_regex = %r{/(?:\w+/)*[\w-]+\.pdf\b}
          password_regex = /(input_pw).*?(output)/
          sanitized_message = e.message.gsub(file_regex, '[FILTERED FILENAME]').gsub(password_regex, '\1 [FILTERED] \2')
          Rails.logger.warn(sanitized_message)
          has_pdf_err = true
        end

        # This helps prevent leaking exception context to DataDog when we raise this error
        if has_pdf_err
          raise Common::Exceptions::UnprocessableEntity.new(
            detail: I18n.t('errors.messages.uploads.pdf.incorrect_password'),
            source: 'IvcChampva::V1::UploadsController'
          )
        end

        destination_file
      end

      def submit_supporting_documents # rubocop:disable Metrics/MethodLength
        if %w[10-10D 10-7959C 10-7959F-2 10-7959A 10-10D-EXTENDED].include?(params[:form_id])
          attachment = PersistentAttachments::MilitaryRecords.new(form_id: params[:form_id])

          Rails.logger.info "submit_supporting_documents called for form #{params[:form_id]}"

          unlocked = unlock_file(params['file'], params['password'])
          attachment.file = params['password'] ? unlocked : params['file']

          # pre-validation logging to help debug issues
          Rails.logger.info "submit_supporting_documents attachment.file class: #{attachment.file.class}"
          Rails.logger.info "submit_supporting_documents attachment.file present: #{attachment.file.present?}"
          Rails.logger.info(
            "submit_supporting_documents attachment.file size: #{number_to_human_size(attachment.file&.size)}"
          )

          unless attachment.valid?
            error_msgs = attachment.errors.full_messages.join(', ')
            Rails.logger.error "submit_supporting_documents attachment is invalid: #{error_msgs}"
            raise Common::Exceptions::ValidationErrors, attachment
          end

          # Convert to PDF before save to reduce final submission latency
          if Flipper.enabled?(:champva_convert_to_pdf_on_upload, @current_user)
            attachment.file = convert_to_pdf(attachment.file)
          end

          attachment.save

          launch_background_job(attachment, params[:form_id].to_s, params['attachment_id'])

          if Flipper.enabled?(:champva_claims_llm_validation, @current_user)
            # Prepare the base response
            response_data = PersistentAttachmentSerializer.new(attachment).serializable_hash

            # Add LLM analysis if enabled
            llm_result = call_llm_service(attachment, params[:form_id], params['attachment_id'])
            response_data[:llm_response] = llm_result if llm_result.present?

            render json: response_data
          else
            render json: PersistentAttachmentSerializer.new(attachment)
          end
        else
          raise Common::Exceptions::UnprocessableEntity.new(
            detail: "Unsupported form_id: #{params[:form_id]}",
            source: 'IvcChampva::V1::UploadsController'
          )
        end
      end

      ##
      # Launches background jobs for OCR and LLM processing if enabled
      # @param [PersistentAttachments::MilitaryRecords] attachment Persistent attachment object for the uploaded file
      # @param [String] form_id The ID of the current form, e.g., 'vha_10_10d' (see FORM_NUMBER_MAP)
      def launch_background_job(attachment, form_id, attachment_id)
        launch_ocr_job(form_id, attachment, attachment_id)
        launch_llm_job(form_id, attachment, attachment_id)
      rescue Errno::ENOENT
        # Do not log the error details because they may contain PII
        Rails.logger.error 'Unhandled ENOENT error while launching background job(s)'
      rescue => e
        Rails.logger.error "Unhandled error while launching background job(s): #{e.message}"
      end

      def launch_ocr_job(form_id, attachment, attachment_id)
        if Flipper.enabled?(:champva_enable_ocr_on_submit, @current_user) && form_id == '10-7959A'
          begin
            # queue Tesseract OCR job for tmpfile
            IvcChampva::TesseractOcrLoggerJob.perform_async(form_id, attachment.guid, attachment.id, attachment_id,
                                                            @current_user)
            Rails.logger.info(
              "Tesseract OCR job queued for form_id: #{form_id}, attachment_id: #{attachment.guid}"
            )
          rescue => e
            Rails.logger.error "Error launching OCR job: #{e.message}"
          end
        end
      end

      def launch_llm_job(form_id, attachment, attachment_id)
        if Flipper.enabled?(:champva_enable_llm_on_submit, @current_user) && form_id == '10-7959A'
          begin
            # queue LLM job for attachment record
            IvcChampva::LlmLoggerJob.perform_async(form_id, attachment.guid, attachment.id, attachment_id,
                                                   @current_user)
            Rails.logger.info(
              "LLM job queued for form_id: #{form_id}, attachment_id: #{attachment.guid}"
            )
          rescue => e
            Rails.logger.error "Error launching LLM job: #{e.message}"
          end
        end
      end

      ##
      # Calls the LLM service synchronously for immediate response
      # @param [PersistentAttachments::MilitaryRecords] attachment The attachment object containing the file
      # @param [String] form_id The mapped form ID (e.g., '10-7959A')
      # @param [String] attachment_id The document type/attachment ID
      # @return [Hash, nil] LLM analysis result or nil if conditions not met
      def call_llm_service(attachment, form_id, attachment_id)
        return nil unless Flipper.enabled?(:champva_claims_llm_validation, @current_user)
        return nil unless form_id == '10-7959A'

        begin
          # create a temp file from the persistent attachment object
          tmpfile = tempfile_from_attachment(attachment, form_id)
          pdf_path = Common::ConvertToPdf.new(tmpfile).run

          # Convert form_id to mapped format for LLM service
          mapped_form_id = FORM_NUMBER_MAP[form_id]

          # Call LLM service synchronously
          llm_service = IvcChampva::LlmService.new
          llm_service.process_document(
            form_id: mapped_form_id,
            file_path: pdf_path,
            uuid: attachment.guid,
            attachment_id:
          )
        rescue => e
          Rails.logger.error "Error calling LLM service: #{e.message}"
          nil
        end
      end

      ## Saves the attached file as a temporary file
      # @param [PersistentAttachments::MilitaryRecords] attachment The attachment object containing the file
      # @param [String] form_id The ID of the current form, e.g., 'vha_10_10d' (see FORM_NUMBER_MAP)
      def tempfile_from_attachment(attachment, form_id)
        original_filename = if attachment.file.respond_to?(:original_filename)
                              attachment.file.original_filename
                            else
                              File.basename(attachment.file.path)
                            end
        # base = File.basename(original_filename, File.extname(original_filename))
        ext = File.extname(original_filename)
        tmpfile = Tempfile.new(["#{form_id}_attachment_", ext]) # a timestamp and unique ID are added automatically
        tmpfile.binmode
        tmpfile.write(attachment.file.read)
        tmpfile.flush
        tmpfile.rewind

        content_type = if attachment.file.respond_to?(:content_type)
                         attachment.file.content_type
                       else
                         content_type_from_extension(ext)
                       end

        # Define content_type method on the tmpfile singleton
        tmpfile.define_singleton_method(:content_type) { content_type }

        tmpfile
      end

      private

      def content_type_from_extension(ext)
        case ext.downcase
        when '.pdf'
          'application/pdf'
        when '.jpg', '.jpeg'
          'image/jpeg'
        when '.png'
          'image/png'
        else
          'application/octet-stream'
        end
      end

      ##
      # Converts an uploaded file to PDF if it's an image. Returns the file unchanged if already a PDF.
      #
      # @param uploaded_file [ActionDispatch::Http::UploadedFile] The file to convert
      # @return [ActionDispatch::Http::UploadedFile] The converted PDF or original file
      # @raise [StandardError] If PDF conversion fails
      def convert_to_pdf(uploaded_file)
        return uploaded_file if uploaded_file.content_type == 'application/pdf'

        tempfile = IvcChampva::PdfConverter.new(uploaded_file).convert_to_tempfile
        pdf_filename = uploaded_file.original_filename.sub(/\.[^.]+\z/, '.pdf')

        ActionDispatch::Http::UploadedFile.new(
          tempfile:,
          filename: pdf_filename,
          type: 'application/pdf'
        )
      end

      def applicants_with_ohi(applicants)
        applicants.select do |item|
          item.key?('health_insurance') || item.key?('medicare')
        end
      end

      ##
      # Generates OHI form instances for a single applicant.
      # Creates one form per 2 health insurance policies to handle overflow
      # when an applicant has more than 2 policies.
      #
      # @param applicant [Hash] Applicant data containing health_insurance array
      # @param form_data [Hash] Complete form submission data (form-level fields)
      # @return [Array<IvcChampva::VHA107959cRev2025>] Array of form instances
      def generate_ohi_form(applicant, form_data)
        forms = []
        health_insurance = applicant['health_insurance'] || [{}]

        health_insurance.each_slice(2) do |policies_pair|
          applicant_data = form_data.except('applicants', 'raw_data', 'medicare').merge(applicant)
          applicant_data['form_number'] = '10-7959C-REV2025'

          if Flipper.enabled?(:champva_form_10_7959c_rev2025, @current_user)
            # NEW: Pass health_insurance array, constructor handles flattening
            applicant_data['health_insurance'] = policies_pair
            forms << IvcChampva::VHA107959cRev2025.new(applicant_data)
          else
            # OLD: Manually map policies to applicant_primary_*/applicant_secondary_* fields
            applicant_with_mapped_policies = map_policies_to_applicant(policies_pair, applicant_data)
            form = IvcChampva::VHA107959cRev2025.new(applicant_with_mapped_policies)
            form.data['form_number'] = '10-7959C-REV2025'
            forms << form
          end
        end

        forms
      end

      ##
      # Sets the primary/secondary health insurance properties on the provided
      # applicant based on a pair of policies. This is so that we can automatically
      # get the keys/values needed to generate overflow OHI forms in the event
      # an applicant is associated with > 2 health insurance policies
      #
      # @param [Array<Hash>] policies Array of hashes representing insurance policies.
      # @param [Hash] applicant Hash representing an applicant object from a 10-10d/10-7959c form
      #
      # @returns [Hash] Updated applicant hash with the primary/secondary insurances mapped
      # so an OHI (10-7959c) PDF can be stamped with this info
      #
      def map_policies_to_applicant(policies, applicant)
        # Create a copy of the applicant hash to avoid modifying the original
        updated_applicant = Marshal.load(Marshal.dump(applicant))

        # Map primary and secondary insurance policies
        map_primary_policy_to_applicant(policies[0], updated_applicant) if policies&.[](0)
        map_secondary_policy_to_applicant(policies[1], updated_applicant) if policies&.[](1)

        updated_applicant
      end

      ##
      # Maps primary insurance policy fields to the applicant hash
      #
      # @param [Hash] policy Primary insurance policy data
      # @param [Hash] applicant Applicant hash to update
      #
      def map_primary_policy_to_applicant(policy, applicant)
        applicant['applicant_primary_provider'] = policy['provider']
        applicant['applicant_primary_effective_date'] = policy['effective_date']
        applicant['applicant_primary_expiration_date'] = policy['expiration_date']
        applicant['applicant_primary_through_employer'] = policy['through_employer']
        applicant['applicant_primary_insurance_type'] = policy['insurance_type']
        applicant['applicant_primary_eob'] = policy['eob']
        applicant['primary_medigap_plan'] = policy['medigap_plan']
        applicant['primary_additional_comments'] = policy['additional_comments']
      end

      ##
      # Maps secondary insurance policy fields to the applicant hash
      #
      # @param [Hash] policy Secondary insurance policy data
      # @param [Hash] applicant Applicant hash to update
      #
      def map_secondary_policy_to_applicant(policy, applicant)
        applicant['applicant_secondary_provider'] = policy['provider']
        applicant['applicant_secondary_effective_date'] = policy['effective_date']
        applicant['applicant_secondary_expiration_date'] = policy['expiration_date']
        applicant['applicant_secondary_through_employer'] = policy['through_employer']
        applicant['applicant_secondary_insurance_type'] = policy['insurance_type']
        applicant['applicant_secondary_eob'] = policy['eob']
        applicant['secondary_medigap_plan'] = policy['medigap_plan']
        applicant['secondary_additional_comments'] = policy['additional_comments']
      end

      def fill_ohi_and_return_path(form)
        # Generate PDF
        filler = IvcChampva::PdfFiller.new(form_number: 'vha_10_7959c_rev2025', form:, uuid: form.uuid)
        # Results in a file path, which is returned
        if @current_user
          filler.generate(@current_user.loa[:current])
        else
          filler.generate
        end
      end

      def create_custom_attachment(form, file_path, attachment_id)
        # Create attachment
        attachment = PersistentAttachments::MilitaryRecords.new(form_id: form.form_id)

        begin
          File.open(file_path, 'rb') do |file|
            attachment.file = file
            attachment.save
          end

          # Clean up the file
          FileUtils.rm_f(file_path)

          IvcChampva::Attachments.serialize_attachment(attachment, attachment_id)
        rescue => e
          Rails.logger.error "Failed to process new custom attachment: #{e.message}"
          FileUtils.rm_f(file_path)
          raise
        end
      end

      # Probably doesn't need to be its own method, but trying to keep methods
      # short by splitting out as much as possible
      def add_supporting_doc(form_data, doc)
        form_data['supporting_docs'] ||= []
        form_data['supporting_docs'] << doc
      end

      # Probably doesn't need to be its own method, but trying to keep methods
      # short by splitting out as much as possible
      def log_error_and_respond(message, exception = nil)
        Rails.logger.error message
        Rails.logger.error exception.backtrace.join("\n") if exception
        render json: { error_message: message }, status: :internal_server_error
      end

      ##
      # Wraps handle_uploads and includes retry logic when file uploads get non-200s.
      #
      # TODO: Remove this method once `champva_send_to_ves` feature flag is removed
      # also consider renaming new 'upload_form' methods back to 'handle_file_uploads'
      #
      # @param [String] form_id The ID of the current form, e.g., 'vha_10_10d' (see FORM_NUMBER_MAP)
      # @param [Hash] parsed_form_data complete form submission data object
      #
      # @return [Array<Integer, String>] An array with 1 or more http status codes
      #   and an array with 1 or more message strings.
      def handle_file_uploads(form_id, parsed_form_data)
        attempt = 0
        max_attempts = 1

        # Initialize with default values to handle nil reference cases
        statuses = [500]
        error_messages = ['Server error occurred']

        begin
          file_paths, metadata = get_file_paths_and_metadata(parsed_form_data)
          hu_result = FileUploader.new(form_id, metadata, file_paths, true, @current_user).handle_uploads
          # convert [[200, nil], [400, 'error']] -> [200, 400] and [nil, 'error'] arrays
          statuses, error_messages = hu_result[0].is_a?(Array) ? hu_result.transpose : hu_result.map { |i| Array(i) }

          # Since some or all of the files failed to upload to S3, trigger retry
          raise StandardError, error_messages if error_messages.compact.length.positive?
        rescue => e
          attempt += 1
          error_message_downcase = e.message.downcase
          Rails.logger.error "Error handling file uploads (attempt #{attempt}): #{e.message}"

          if should_retry?(error_message_downcase, attempt, max_attempts)
            Rails.logger.error 'Retrying in 1 seconds...'
            sleep 1
            retry
          end
        end

        [statuses, error_messages]
      end

      ##
      # Wraps handle_uploads and includes retry logic when file uploads get non-200s.
      #
      # TODO: Rename this method once `champva_send_to_ves` feature flag is removed back to 'handle_file_uploads'
      #
      # @param [String] form_id The ID of the current form, e.g., 'vha_10_10d' (see FORM_NUMBER_MAP)
      # @param [Array<String>] file_paths The file paths of the files to upload
      # @param [Hash] metadata The metadata for the form
      #
      # @return [Array<Integer, String>] An array with 1 or more http status codes
      #   and an array with 1 or more message strings.
      def upload_form(form_id, file_paths, metadata)
        attempt = 0
        max_attempts = 1

        # Initialize with default values to handle nil reference cases
        statuses = [500]
        error_messages = ['Server error occurred']

        begin
          hu_result = FileUploader.new(form_id, metadata, file_paths, true).handle_uploads
          # convert [[200, nil], [400, 'error']] -> [200, 400] and [nil, 'error'] arrays
          statuses, error_messages = hu_result[0].is_a?(Array) ? hu_result.transpose : hu_result.map { |i| Array(i) }

          # Since some or all of the files failed to upload to S3, trigger retry
          raise StandardError, error_messages if error_messages.compact.length.positive?
        rescue => e
          attempt += 1
          error_message_downcase = e.message.downcase
          Rails.logger.error "Error handling file uploads (attempt #{attempt}): #{e.message}"

          if should_retry?(error_message_downcase, attempt, max_attempts)
            Rails.logger.error 'Retrying in 1 seconds...'
            sleep 1
            retry
          end
        end

        [statuses, error_messages]
      end

      ##
      # Handles file uploads with a refactored retry logic
      #
      # @param [String] form_id The ID of the current form, e.g., 'vha_10_10d' (see FORM_NUMBER_MAP)
      # @param [Hash] parsed_form_data complete form submission data object
      #
      # @return [Array<Integer, String>] An array with 1 or more http status codes
      #   and an array with 1 or more message strings.
      def handle_file_uploads_with_refactored_retry(form_id, parsed_form_data)
        on_failure = lambda { |e, attempt|
          Rails.logger.error "Error handling file uploads (attempt #{attempt}): #{e.message}"
        }

        # set default values for statuses and error_messages to avoid nil reference errors
        statuses = [500]
        error_messages = ['Server error occurred']

        IvcChampva::Retry.do(1, retry_on: RETRY_ERROR_CONDITIONS, on_failure:) do
          file_paths, metadata = get_file_paths_and_metadata(parsed_form_data)
          hu_result = FileUploader.new(form_id, metadata, file_paths, true, @current_user).handle_uploads
          # convert [[200, nil], [400, 'error']] -> [200, 400] and [nil, 'error'] arrays
          statuses, error_messages = hu_result[0].is_a?(Array) ? hu_result.transpose : hu_result.map { |i| Array(i) }

          # Since some or all of the files failed to upload to S3, trigger retry
          raise StandardError, error_messages if error_messages.compact.length.positive?
        end

        [statuses, error_messages]
      end

      ##
      # Handles file uploads with a refactored retry logic
      #
      # @param [String] form_id The ID of the current form, e.g., 'vha_10_10d' (see FORM_NUMBER_MAP)
      # @param [Array<String>] file_paths The file paths of the files to upload
      # @param [Hash] metadata The metadata for the form
      #
      # @return [Array<Integer, String>] An array with 1 or more http status codes
      #   and an array with 1 or more message strings.
      def upload_form_with_refactored_retry(form_id, file_paths, metadata)
        on_failure = lambda { |e, attempt|
          Rails.logger.error "Error handling file uploads (attempt #{attempt}): #{e.message}"
        }

        # set default values for statuses and error_messages to avoid nil reference errors
        statuses = [500]
        error_messages = ['Server error occurred']

        IvcChampva::Retry.do(1, retry_on: RETRY_ERROR_CONDITIONS, on_failure:) do
          hu_result = FileUploader.new(form_id, metadata, file_paths, true).handle_uploads
          # convert [[200, nil], [400, 'error']] -> [200, 400] and [nil, 'error'] arrays
          statuses, error_messages = hu_result[0].is_a?(Array) ? hu_result.transpose : hu_result.map { |i| Array(i) }

          # Since some or all of the files failed to upload to S3, trigger retry
          raise StandardError, error_messages if error_messages.compact.length.positive?
        end

        [statuses, error_messages]
      end

      def should_retry?(error_message_downcase, attempt, max_attempts)
        error_conditions = [
          'failed to generate',
          'no such file',
          'an error occurred while verifying stamp:',
          'unable to find file'
        ]

        error_conditions.any? { |condition| error_message_downcase.include?(condition) } && attempt <= max_attempts
      end

      def get_attachment_ids_and_form(parsed_form_data)
        base_form_id = get_form_id
        form = IvcChampva::FormVersionManager.create_form_instance(base_form_id, parsed_form_data, @current_user)

        form_class = form.class
        additional_pdf_count = form_class.const_defined?(:ADDITIONAL_PDF_COUNT) ? form_class::ADDITIONAL_PDF_COUNT : 1
        applicant_key = form_class.const_defined?(:ADDITIONAL_PDF_KEY) ? form_class::ADDITIONAL_PDF_KEY : 'applicants'

        applicants_count = parsed_form_data[applicant_key]&.count.to_i
        total_applicants_count = applicants_count.to_f / additional_pdf_count
        # Must always be at least 1, so that `attachment_ids` still contains the
        # `form_id` even on forms that don't have an `applicants` array (e.g. FMP2)
        applicant_rounded_number = total_applicants_count.ceil.zero? ? 1 : total_applicants_count.ceil

        # Optionally add a supporting document with arbitrary form-defined values.
        add_blank_doc_and_stamp(form, parsed_form_data)

        # DataDog Tracking
        form.track_user_identity
        form.track_current_user_loa(@current_user)
        form.track_email_usage

        if Flipper.enabled?(:champva_update_datadog_tracking, @current_user) && form.respond_to?(:track_submission)
          form.track_submission(@current_user)
        end

        attachment_ids = build_attachment_ids(base_form_id, parsed_form_data, applicant_rounded_number)
        attachment_ids = [base_form_id] if attachment_ids.empty?

        [attachment_ids.compact, form]
      end

      def supporting_document_ids(parsed_form_data)
        cached_uploads = []
        parsed_form_data['supporting_docs']&.each do |d|
          # Get the database record that corresponds to this file upload:
          record = PersistentAttachments::MilitaryRecords.find_by(guid: d['confirmation_code'])
          # Push to our array with some extra information so we can sort by date uploaded:
          cached_uploads.push({ attachment_id: d['attachment_id'],
                                created_at: record.created_at,
                                file_name: record.file.id })
        end

        # Sort by date created so we have the file's upload order and
        # reduce down to just the attachment id strings:
        attachment_ids = cached_uploads.sort_by { |h| h[:created_at] }.pluck(:attachment_id)&.compact.presence

        # Return either the attachment IDs or `claim_id`s (fallback for form 10-7959a):
        attachment_ids || parsed_form_data['supporting_docs']&.pluck('attachment_id')&.compact.presence ||
          parsed_form_data['supporting_docs']&.pluck('claim_id')&.compact.presence || []
      end

      ##
      # Builds the attachment_ids array for the given form submission.
      # For 10-7959a resubmissions:
      #  - If Control number selected: the main claim sheet is labeled "CVA Reopen",
      #    supporting docs retain original types.
      #  - If PDI selected: use the standard logic because the generated stamped doc
      #    (created in stamp_metadata) is labeled "CVA Bene Response" by the model, and
      #    supporting docs retain original types. Main claim sheet remains the default
      #    form_id.
      # For all other cases, uses the standard logic.
      #
      # @param [String] form_id The mapped form ID (e.g., 'vha_10_7959a')
      # @param [Hash] parsed_form_data complete form submission data object
      # @param [Integer] applicant_rounded_number number of main form attachments needed
      # @return [Array<String>] array of attachment_ids for all documents
      def build_attachment_ids(form_id, parsed_form_data, applicant_rounded_number)
        if Flipper.enabled?(:champva_resubmission_attachment_ids) &&
           form_id == 'vha_10_7959a' &&
           parsed_form_data['claim_status'] == 'resubmission'
          selector = parsed_form_data['pdi_or_claim_number']

          if selector == 'Control number'
            # Relabel main claim sheet as CVA Reopen; supporting docs retain original types.
            main = Array.new(applicant_rounded_number) { 'CVA Reopen' }
            main.concat(supporting_document_ids(parsed_form_data))
          elsif selector == 'PDI number'
            # Main form keeps default form_id; all supporting docs get relabeled to "CVA Bene Response".
            build_pdi_resubmission_attachment_ids(form_id, parsed_form_data, applicant_rounded_number)
          else
            build_default_attachment_ids(form_id, parsed_form_data, applicant_rounded_number)
          end
        else
          build_default_attachment_ids(form_id, parsed_form_data, applicant_rounded_number)
        end
      end

      ##
      # Builds the default attachment_ids array using the standard logic.
      #
      # @param [String] form_id The mapped form ID
      # @param [Hash] parsed_form_data complete form submission data object
      # @param [Integer] applicant_rounded_number number of main form attachments needed
      # @return [Array<String>] array of attachment_ids
      def build_default_attachment_ids(form_id, parsed_form_data, applicant_rounded_number)
        attachment_ids = Array.new(applicant_rounded_number) { form_id }
        attachment_ids.concat(supporting_document_ids(parsed_form_data))
      end

      ##
      # Builds the attachment_ids array for PDI number resubmissions.
      # All documents (main form and supporting docs) are labeled "CVA Bene Response".
      #
      # @param [String] _form_id The mapped form ID (unused, all docs get same label)
      # @param [Hash] parsed_form_data complete form submission data object
      # @param [Integer] applicant_rounded_number number of main form attachments needed
      # @return [Array<String>] array of attachment_ids
      def build_pdi_resubmission_attachment_ids(_form_id, parsed_form_data, applicant_rounded_number)
        supporting_doc_count = parsed_form_data['supporting_docs']&.count.to_i
        total_doc_count = applicant_rounded_number + supporting_doc_count
        Array.new(total_doc_count) { 'CVA Bene Response' }
      end

      ##
      # Add a blank page to the PDF with stamped metadata if the form allows it.
      #
      # This method checks if the form has a `stamp_metadata` method that returns a hash.
      # If so, it creates a blank page, stamps it with the provided metadata values,
      # and adds it as a supporting document to the parsed form data.
      #
      # @param form [Object] The form object that may contain stamp_metadata method
      # @param parsed_form_data [Hash] The parsed form data where the supporting document will be added
      # @return [nil] This method doesn't return any value
      def add_blank_doc_and_stamp(form, parsed_form_data)
        # Only triggers if the form in question has a method that returns values
        # we want to stamp.
        if form.methods.include?(:stamp_metadata)
          stamps = form.stamp_metadata

          if !stamps.nil? && stamps.is_a?(Hash)
            blank_page_path = IvcChampva::Attachments.get_blank_page
            IvcChampva::PdfStamper.stamp_metadata_items(blank_page_path, stamps[:metadata])
            att = create_custom_attachment(form, blank_page_path, stamps[:attachment_id])
            add_supporting_doc(parsed_form_data, att)
          end
        end
      end

      def get_file_paths_and_metadata(parsed_form_data)
        attachment_ids, form = get_attachment_ids_and_form(parsed_form_data)

        # Use the actual form ID for PDF generation, but legacy form ID for S3/metadata
        actual_form_id = form.form_id
        legacy_form_id = IvcChampva::FormVersionManager.get_legacy_form_id(actual_form_id)

        filler = IvcChampva::PdfFiller.new(form_number: actual_form_id, form:, uuid: form.uuid, name: legacy_form_id)

        file_path = if @current_user
                      filler.generate(@current_user.loa[:current])
                    else
                      filler.generate
                    end

        # Get validated metadata
        metadata = IvcChampva::MetadataValidator.validate(form.metadata)

        file_paths = form.handle_attachments(file_path)

        # Generate VES JSON file and add to file_paths if conditions are met
        if should_generate_ves_json?(form.form_id)
          ves_json_path = generate_ves_json_file(form, parsed_form_data)
          if ves_json_path
            file_paths << ves_json_path
            attachment_ids << 'VES JSON'
          end
        end

        [file_paths, metadata.merge({ 'attachment_ids' => attachment_ids })]
      end

      def get_form_id
        form_number = params[:form_number]
        raise 'Missing/malformed form_number in params' unless form_number

        FORM_NUMBER_MAP[form_number]
      end

      def build_json(statuses, error_message)
        if statuses.nil?
          return { json: { error_message: 'An unknown error occurred while uploading document(s).' }, status: 500 }
        end

        unique_statuses = statuses.uniq

        if unique_statuses == [200]
          { json: {}, status: 200 }
        elsif unique_statuses.include? 400
          { json: { error_message: error_message ||
            'An unknown error occurred while uploading some documents.' }, status: 400 }
        else
          { json: { error_message: 'An unknown error occurred while uploading document(s).' }, status: 500 }
        end
      end

      def authenticate
        super
      rescue Common::Exceptions::Unauthorized
        Rails.logger.info(
          'IVC Champva - unauthenticated user submitting form',
          { form_number: params[:form_number] }
        )
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
