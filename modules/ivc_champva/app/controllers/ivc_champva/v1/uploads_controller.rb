# frozen_string_literal: true

require 'datadog'
require 'ves_api/client'

module IvcChampva
  module V1
    class UploadsController < ApplicationController
      skip_after_action :set_csrf_header

      FORM_NUMBER_MAP = {
        '10-10D' => 'vha_10_10d',
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

      def submit
        Datadog::Tracing.trace('Start IVC File Submission') do
          form_id = get_form_id
          Datadog::Tracing.active_trace&.set_tag('form_id', form_id)
          parsed_form_data = JSON.parse(params.to_json)

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

      ##
      # Handles PEGA/S3 file uploads and VES submission
      #
      # @param [String] form_id The ID of the current form, e.g., 'vha_10_10d' (see FORM_NUMBER_MAP)
      # @param [Hash] parsed_form_data complete form submission data object
      #
      # @return [Hash] response from build_json
      def handle_file_uploads_wrapper(form_id, parsed_form_data)
        if Flipper.enabled?(:champva_send_to_ves, @current_user) &&
           Settings.vsp_environment != 'production' && form_id == 'vha_10_10d'
          # first, prepare and validate the VES request
          ves_request = prepare_ves_request(parsed_form_data)

          # get file_paths and metadata so we can use the metadata to update the VES records
          file_paths, metadata = get_file_paths_and_metadata(parsed_form_data)

          # call handle_file_uploads with new signature
          statuses, error_messages = call_upload_form(form_id, file_paths, metadata)

          response = build_json(statuses, error_messages)

          # if the response is successful, submit the VES request
          submit_ves_request(ves_request, metadata) if response[:status] == 200

          response
        else
          statuses, error_messages = call_handle_file_uploads(form_id, parsed_form_data)

          build_json(statuses, error_messages)
        end
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
      def unlock_file(file, file_password) # rubocop:disable Metrics/MethodLength
        return file unless File.extname(file) == '.pdf' && file_password

        pdftk = PdfForms.new(Settings.binaries.pdftk)
        tmpf = Tempfile.new(['decrypted_form_attachment', '.pdf'])

        has_pdf_err = false
        begin
          pdftk.call_pdftk(file.tempfile.path, 'input_pw', file_password, 'output', tmpf.path)
        rescue PdfForms::PdftkError => e
          file_regex = %r{/(?:\w+/)*[\w-]+\.pdf\b}
          password_regex = /(input_pw).*?(output)/
          sanitized_message = e.message.gsub(file_regex, '[FILTERED FILENAME]').gsub(password_regex, '\1 [FILTERED] \2')
          log_message_to_sentry(sanitized_message, 'warn')
          has_pdf_err = true
        end

        # This helps prevent leaking exception context to DataDog when we raise this error
        if has_pdf_err
          raise Common::Exceptions::UnprocessableEntity.new(
            detail: I18n.t('errors.messages.uploads.pdf.incorrect_password'),
            source: 'IvcChampva::V1::UploadsController'
          )
        end

        file.tempfile.unlink
        file.tempfile = tmpf
      end

      def submit_supporting_documents
        if %w[10-10D 10-7959C 10-7959F-2 10-7959A].include?(params[:form_id])
          attachment = PersistentAttachments::MilitaryRecords.new(form_id: params[:form_id])

          unlocked = unlock_file(params['file'], params['password'])
          attachment.file = params['password'] ? unlocked : params['file']
          raise Common::Exceptions::ValidationErrors, attachment unless attachment.valid?

          attachment.save
          render json: PersistentAttachmentSerializer.new(attachment)
        else
          raise Common::Exceptions::UnprocessableEntity.new(
            detail: "Unsupported form_id: #{params[:form_id]}",
            source: 'IvcChampva::V1::UploadsController'
          )
        end
      end

      private

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

        statuses = nil
        error_messages = nil

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

        statuses = nil
        error_messages = nil

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
        form_id = get_form_id
        form_class = "IvcChampva::#{form_id.titleize.gsub(' ', '')}".constantize
        additional_pdf_count = form_class.const_defined?(:ADDITIONAL_PDF_COUNT) ? form_class::ADDITIONAL_PDF_COUNT : 1
        applicant_key = form_class.const_defined?(:ADDITIONAL_PDF_KEY) ? form_class::ADDITIONAL_PDF_KEY : 'applicants'

        applicants_count = parsed_form_data[applicant_key]&.count.to_i
        total_applicants_count = applicants_count.to_f / additional_pdf_count
        # Must always be at least 1, so that `attachment_ids` still contains the
        # `form_id` even on forms that don't have an `applicants` array (e.g. FMP2)
        applicant_rounded_number = total_applicants_count.ceil.zero? ? 1 : total_applicants_count.ceil

        form = form_class.new(parsed_form_data)
        # DataDog Tracking
        form.track_user_identity
        form.track_current_user_loa(@current_user)
        form.track_email_usage

        attachment_ids = Array.new(applicant_rounded_number) { form_id }
        attachment_ids.concat(supporting_document_ids(parsed_form_data))
        attachment_ids = [form_id] if attachment_ids.empty?

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

        # Return either the attachment IDs or `claim_id`s (in the case of form 10-7959a):
        attachment_ids || parsed_form_data['supporting_docs']&.pluck('claim_id')&.compact.presence || []
      end

      def get_file_paths_and_metadata(parsed_form_data)
        attachment_ids, form = get_attachment_ids_and_form(parsed_form_data)

        filler = IvcChampva::PdfFiller.new(form_number: form.form_id, form:, uuid: form.uuid)
        file_path = if @current_user
                      filler.generate(@current_user.loa[:current])
                    else
                      filler.generate
                    end
        metadata = IvcChampva::MetadataValidator.validate(form.metadata)
        file_paths = form.handle_attachments(file_path)

        [file_paths, metadata.merge({ 'attachment_ids' => attachment_ids })]
      end

      def get_form_id
        form_number = params[:form_number]
        raise 'Missing/malformed form_number in params' unless form_number

        FORM_NUMBER_MAP[form_number]
      end

      def build_json(statuses, error_message)
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
