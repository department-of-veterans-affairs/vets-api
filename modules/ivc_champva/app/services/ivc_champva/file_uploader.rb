# frozen_string_literal: true

module IvcChampva
  class FileUploader
    def initialize(form_id, metadata, file_paths, attachment_ids, insert_db_row = false) # rubocop:disable Style/OptionalBooleanParameter
      @form_id = form_id
      @metadata = metadata || {}
      @file_paths = Array(file_paths)
      @attachment_ids = attachment_ids
      @insert_db_row = insert_db_row
    end

    def handle_uploads
      results = @attachment_ids.zip(@file_paths).map do |attachment_id, file_path|
        next unless attachment_id != 'Form ID'

        response_status = upload_file(attachment_id, file_path)
        insert_form(file_path.gsub('tmp/', '').gsub('-tmp', ''), response_status.to_s) if @insert_db_row

        response_status
      end.compact

      all_success = results.all? { |(status, _)| status == 200 }

      if all_success
        generate_and_upload_meta_json
      else
        results
      end
    end

    private

    def insert_form(file_path, response_status)
      pega_status = response_status.first == 200 ? 'Submitted' : nil
      IvcChampvaForm.create!(
        form_uuid: @metadata['uuid'],
        email: validate_email(@metadata&.dig('primaryContactInfo', 'email')),
        first_name: @metadata&.dig('primaryContactInfo', 'name', 'first'),
        last_name: @metadata&.dig('primaryContactInfo', 'name', 'last'),
        form_number: @metadata['docType'],
        file_name: file_path,
        s3_status: response_status,
        pega_status:
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Database Insertion Error for #{@metadata['uuid']}: #{e.message}")
    end

    def upload_file(attachment_id, file_path)
      file_name = file_path.gsub('tmp/', '').gsub('-tmp', '')
      upload(file_name, file_path, attachment_ids: [attachment_id])
    end

    def generate_and_upload_meta_json
      meta_file_name = "#{@metadata['uuid']}_#{@form_id}_metadata.json"
      meta_file_path = "tmp/#{meta_file_name}"
      File.write(meta_file_path, @metadata.to_json)
      meta_upload_status, meta_upload_error_message = upload(meta_file_name,
                                                             meta_file_path,
                                                             attachment_ids: @attachment_ids)

      if meta_upload_status == 200
        FileUtils.rm_f(meta_file_path)
        [meta_upload_status, nil]
      else
        [meta_upload_status, meta_upload_error_message]
      end
    end

    def upload(file_name, file_path, attachment_ids:)
      case client.put_object(file_name, file_path, @metadata.except('primaryContactInfo'), attachment_ids)
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

    def validate_email(email)
      return nil unless email.present? && email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i)

      email
    end
  end
end
