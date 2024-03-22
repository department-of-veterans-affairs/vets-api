# frozen_string_literal: true

require 'ddtrace'

module IvcChampva
  module V1
    class UploadsController < ApplicationController
      skip_after_action :set_csrf_header

      FORM_NUMBER_MAP = {
        '10-10D' => 'vha_10_10d',
        '10-7959F-1' => 'vha_10_7959f_1',
        '10-7959F-2' => 'vha_10_7959f_2'
      }.freeze

      def submit
        Datadog::Tracing.active_trace&.set_tag('form_id', params[:form_number])
        form_id = get_form_id
        parsed_form_data = JSON.parse(params.to_json)
        file_path, file_paths, metadata, form = get_file_paths_and_metadata(parsed_form_data)

        status, error_message = handle_uploads(form_id, metadata, file_paths)

        render json: get_json(form_id, error_message || nil)

      rescue => e
        raise Exceptions::ScrubbedUploadsSubmitError.new(params), e
      end

      def submit_supporting_documents
        if %w[10-10D].include?(params[:form_id])
          attachment = PersistentAttachments::MilitaryRecords.new(form_id: params[:form_id])
          attachment.file = params['file']
          raise Common::Exceptions::ValidationErrors, attachment unless attachment.valid?

          attachment.save
          render json: attachment
        end
      end

      private

      def handle_uploads(form_id, metadata, pdf_file_paths)
        meta_file_name = "#{form_id}_metadata.json"
        meta_file_path = "tmp/#{meta_file_name}"

        pdf_results =
          pdf_file_paths.map do |pdf_file_path|
            pdf_file_name = pdf_file_path.gsub('tmp/', '').gsub('-tmp', '')
            upload_to_ivc_s3(pdf_file_name, pdf_file_path, metadata)
          end

        all_pdf_success = pdf_results.all? { |(status, _)| status == 200 }

        if all_pdf_success
          File.write(meta_file_path, metadata)
          meta_upload_status, meta_upload_error_message = upload_to_ivc_s3(meta_file_name, meta_file_path)

          if meta_upload_status == 200
            FileUtils.rm_f(meta_file_path)
            [meta_upload_status, nil]
          else
            [meta_upload_status, meta_upload_error_message]
          end
        else
          [pdf_results]
        end
      end

      def get_file_paths_and_metadata(parsed_form_data)
        form_id = get_form_id
        form = "IvcChampva::#{form_id.titleize.gsub(' ', '')}".constantize.new(parsed_form_data)
        filler = IvcChampva::PdfFiller.new(form_number: form_id, form:)

        file_path = if @current_user
                      filler.generate(@current_user.loa[:current])
                    else
                      filler.generate
                    end
        metadata = IvcChampva::MetadataValidator.validate(form.metadata)

        maybe_add_file_paths =
          case form_id
          when 'vba_40_0247', 'vba_20_10207', 'vha_10_10d', 'vba_40_10007'
            form.handle_attachments(file_path)
          else
            [file_path]
          end

        [file_path, maybe_add_file_paths, metadata, form]
      end

      def upload_to_ivc_s3(file_name, file_path, metadata = {})
        case ivc_s3_client.put_object(file_name, file_path, metadata)
        in { success: true }
          [200]
        in { success: false, error_message: error_message }
          [400, error_message]
        else
          [500, 'Unexpected response from S3 upload']
        end
      end

      def get_form_id
        form_number = params[:form_number]
        raise 'missing form_number in params' unless form_number

        FORM_NUMBER_MAP[form_number]
      end

      def get_json(confirmation_number, form_id, error_message)
        json = { confirmation_number: }
        json[:expiration_date] = 1.year.from_now if form_id == 'vba_21_0966'
        json[:error_message] = error_message

        json
      end

      def ivc_s3_client
        @ivc_s3_client ||= IvcChampva::S3.new(
          region: Settings.ivc_forms.s3.region,
          access_key_id: Settings.ivc_forms.s3.aws_access_key_id,
          secret_access_key: Settings.ivc_forms.s3.aws_secret_access_key,
          bucket_name: Settings.ivc_forms.s3.bucket
        )
      end
    end
  end
end
