# frozen_string_literal: true

require 'ddtrace'

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

      def submit
        Datadog::Tracing.trace('Start IVC File Submission') do
          form_id = get_form_id
          Datadog::Tracing.active_trace&.set_tag('form_id', form_id)
          parsed_form_data = JSON.parse(params.to_json)
          statuses, error_message = handle_file_uploads(form_id, parsed_form_data)

          response = build_json(Array(statuses), error_message)

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

      def submit_supporting_documents
        if %w[10-10D 10-7959C 10-7959F-2 10-7959A].include?(params[:form_id])
          attachment = PersistentAttachments::MilitaryRecords.new(form_id: params[:form_id])
          attachment.file = params['file']
          raise Common::Exceptions::ValidationErrors, attachment unless attachment.valid?

          attachment.save
          render json: PersistentAttachmentSerializer.new(attachment)
        end
      end

      private

      if Flipper.enabled?(:champva_multiple_stamp_retry, @current_user)
        def handle_file_uploads(form_id, parsed_form_data)
          attempt = 0
          max_attempts = 1

          begin
            file_paths, metadata = get_file_paths_and_metadata(parsed_form_data)
            file_uploader = FileUploader.new(form_id, metadata, file_paths, true)
            statuses, error_message = file_uploader.handle_uploads
          rescue => e
            attempt += 1
            error_message_downcase = e.message.downcase
            Rails.logger.error "Error handling file uploads (attempt #{attempt}): #{e.message}"

            error_conditions = [
              'failed to generate',
              'no such file',
              'an error occurred while verifying stamp:',
              'unable to find file'
            ]

            if error_conditions.any? do |condition|
              error_message_downcase.include?(condition)
            end && attempt <= max_attempts
              Rails.logger.error 'Retrying in 1 seconds...'
              sleep 1
              retry
            else
              return [[], 'no retries needed']
            end
          end

          [statuses, error_message]
        end
      else
        def handle_file_uploads(form_id, parsed_form_data)
          file_paths, metadata = get_file_paths_and_metadata(parsed_form_data)
          statuses, error_message = FileUploader.new(form_id, metadata, file_paths, true).handle_uploads
          statuses = Array(statuses)

          # Retry attempt if specific error message is found
          if statuses.any? do |status|
            status.is_a?(String) && status.include?('No such file or directory @ rb_sysopen')
          end
            file_paths, metadata = get_file_paths_and_metadata(parsed_form_data)
            statuses, error_message = FileUploader.new(form_id, metadata, file_paths, true).handle_uploads
          end

          [statuses, error_message]
        end
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
