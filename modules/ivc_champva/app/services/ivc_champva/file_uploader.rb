# frozen_string_literal: true

require 'ivc_champva/monitor'

module IvcChampva
  class FileUploader
    def initialize(form_id, metadata, file_paths, insert_db_row = false) # rubocop:disable Style/OptionalBooleanParameter
      @form_id = form_id
      @metadata = metadata || {}
      @file_paths = Array(file_paths)
      @insert_db_row = insert_db_row
    end

    def handle_uploads
      results = @metadata['attachment_ids'].zip(@file_paths).map do |attachment_id, file_path|
        next if file_path.blank?

        file_name = File.basename(file_path).gsub('-tmp', '')
        response_status = upload(file_name, file_path, metadata_for_s3(attachment_id))
        insert_form(file_name, response_status.to_s) if @insert_db_row

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

    def metadata_for_s3(attachment_id)
      key = attachment_id.is_a?(Integer) ? 'claim_id' : 'attachment_id'
      @metadata.except('primaryContactInfo', 'attachment_ids').merge({ key => attachment_id.to_s })
    end

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

      if Flipper.enabled?(:champva_enhanced_monitor_logging, @current_user)
        monitor.track_insert_form(@metadata['uuid'], @form_id)
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Database Insertion Error for #{@metadata['uuid']}: #{e.message}")
    end

    def generate_and_upload_meta_json
      meta_file_name = "#{@metadata['uuid']}_#{@form_id}_metadata.json"
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

    def upload(file_name, file_path, metadata = {})
      case client.put_object(file_name, file_path, metadata)
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
        bucket: Settings.ivc_forms.s3.bucket
      )
    end

    def validate_email(email)
      return nil unless email.present? && email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i)

      email
    end

    ##
    # retreive a monitor for tracking
    #
    # @return [IvcChampva::Monitor]
    #
    def monitor
      @monitor ||= IvcChampva::Monitor.new
    end
  end
end
