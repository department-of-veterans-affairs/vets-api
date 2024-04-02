# frozen_string_literal: true

module IvcChampva
  class FileUploader
    def initialize(form_id, metadata, file_paths)
      @form_id = form_id
      @metadata = metadata || {}
      @file_paths = Array(file_paths)
    end

    def handle_uploads
      pdf_results = @file_paths.map do |pdf_file_path|
        upload_pdf(pdf_file_path)
      end

      all_pdf_success = pdf_results.all? { |(status, _)| status == 200 }

      if all_pdf_success
        generate_and_upload_meta_json
      else
        pdf_results
      end
    end

    private

    def upload_pdf(file_path)
      file_name = file_path.gsub('tmp/', '').gsub('-tmp', '')
      upload(file_name, file_path)
    end

    def generate_and_upload_meta_json
      meta_file_name = "#{@form_id}_metadata.json"
      meta_file_path = "tmp/#{meta_file_name}"

      File.write(meta_file_path, @metadata.to_json)
      meta_upload_status, meta_upload_error_message = upload(meta_file_name, meta_file_path)

      if meta_upload_status == 200
        FileUtils.rm_f(meta_file_path)
        [meta_upload_status, nil]
      else
        [meta_upload_status, meta_upload_error_message]
      end
    end

    def upload(file_name, file_path)
      case client.put_object(file_name, file_path, @metadata)
      in { success: true }
        [200]
      in { success: false, error_message: error_message }
        [400, error_message]
      else
        [500, 'Unexpected response from S3 upload']
      end
    end

    def client
      @client ||= IvcChampva::S3.new(
        region: Settings.ivc_forms.s3.region,
        access_key_id: Settings.ivc_forms.s3.aws_access_key_id,
        secret_access_key: Settings.ivc_forms.s3.aws_secret_access_key,
        bucket: Settings.ivc_forms.s3.bucket
      )
    end
  end
end
