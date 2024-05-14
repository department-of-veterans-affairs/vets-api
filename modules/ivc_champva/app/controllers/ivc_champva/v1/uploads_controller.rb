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
        '10-7959C' => 'vha_10_7959c'
      }.freeze

      def submit
        Datadog::Tracing.trace('Start IVC File Submission') do
          Datadog::Tracing.active_trace&.set_tag('form_id', params[:form_number])
          form_id = get_form_id
          parsed_form_data = JSON.parse(params.to_json)
          file_paths, metadata, attachment_ids = get_file_paths_and_metadata(parsed_form_data)

          status, error_message = FileUploader.new(form_id, metadata, file_paths, attachment_ids).handle_uploads

          render json: build_json(Array(status), error_message)
        rescue => e
          puts 'An unknown error occurred while uploading document(s).'
          Rails.logger.error "Error: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
        end
      end

      def submit_supporting_documents
        if %w[10-10D 10-7959C 10-7959F-2].include?(params[:form_id])
          attachment = PersistentAttachments::MilitaryRecords.new(form_id: params[:form_id])
          attachment.file = params['file']
          raise Common::Exceptions::ValidationErrors, attachment unless attachment.valid?

          attachment.save
          render json: attachment
        end
      end

      private

      def get_attachment_ids_and_form(parsed_form_data)
        form_id = get_form_id
        form = "IvcChampva::#{form_id.titleize.gsub(' ', '')}".constantize.new(parsed_form_data)
        attachment_ids = [form_id]

        if form_id == 'vha_10_10d'
          parsed_form_data['applicants'].each do |applicant|
            next unless applicant.key?('applicant_supporting_documents')

            applicant['applicant_supporting_documents'].each do |documents|
              documents.each do |document|
                attachment_ids << document['attachment_id']
              end
            end
          end
        end
        [attachment_ids, form]
      end

      def get_file_paths_and_metadata(parsed_form_data)
        attachment_ids, form = get_attachment_ids_and_form(parsed_form_data)
        filler = IvcChampva::PdfFiller.new(form_number: form.form_id, form:)
        file_path = if @current_user
                      filler.generate(@current_user.loa[:current])
                    else
                      filler.generate
                    end
        metadata = IvcChampva::MetadataValidator.validate(form.metadata)
        file_paths = form.handle_attachments(file_path)

        [file_paths, metadata, attachment_ids]
      end

      def get_form_id
        form_number = params[:form_number]
        raise 'missing form_number in params' unless form_number
        form_number_without_colon = form_number.sub(':', '')
        FORM_NUMBER_MAP[form_number_without_colon]
      end

      def build_json(status, error_message)
        if status.all? { |s| s == 200 }
          {
            status: 200
          }
        elsif status.all? { |s| s == 400 }
          {
            error_message:,
            status: 400
          }
        elsif status.all? { |s| s == 204 }
          { 
              status: 204 
          } 
        else
          {
            error_message: 'Partial upload failure',
            status: 206
          }
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
