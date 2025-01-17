# frozen_string_literal: true

require 'ivc_champva/monitor'

module IvcChampva
  class FileUploader
    ##
    # Initialize new file uploader
    #
    # @param [String] form_id The ID of the current form, e.g., 'vha_10_10d' (see FORM_NUMBER_MAP)
    # @param [Hash] metadata The metadata accompanying this form submission (see IvcChampva::VHA1010d.metadata example)
    # @param [Array] file_paths List of local file paths of all attachments to be uploaded
    # @param [Boolean] insert_db_row whether or not to record the uploads and S3 responses in the database
    #
    # @return [IvcChampva::FileUploader]
    #
    def initialize(form_id, metadata, file_paths, insert_db_row = false) # rubocop:disable Style/OptionalBooleanParameter
      @form_id = form_id
      @metadata = metadata || {}
      @file_paths = Array(file_paths)
      @insert_db_row = insert_db_row
    end

    ##
    # Coordinates uploading files to S3, checking response statuses, and producing the
    # metadata JSON that alerts the PEGA lambda to ingest the uploaded submission.
    #
    # The return value reflects whether or not all files were successfully uploaded.
    #
    # If successful, it will return an array containing a single HTTP status code and an
    # optional error message, e.g. [200] | [400, 'No such file']
    #
    # If any uploads yield non-200 statuses when submitted to S3, it raise a StandardError.
    #
    # @return [Array<Integer, String>] An array with a status code and an optional error message string.
    def handle_uploads
      results = @metadata['attachment_ids'].zip(@file_paths).map do |attachment_id, file_path|
        next if file_path.blank?

        file_name = File.basename(file_path).gsub('-tmp', '')
        response_status = upload(file_name, file_path, metadata_for_s3(attachment_id))
        insert_form(file_name, response_status.to_s) if @insert_db_row

        response_status
      end.compact

      s3_err = nil
      all_success = results.all? do |(status, err)|
        s3_err = err if err # Collect last error present for logging purposes
        status == 200
      end

      if all_success
        generate_and_upload_meta_json
      else
        # Stop this submission in its tracks - entries will still be added to database
        # for these files, but user will see error on the FE saying submission failed.
        raise StandardError, "IVC ChampVa Forms - failed to upload all documents for submission: #{s3_err}"
      end
    end

    private

    ##
    # Creates a modified metadata hash to be attached to individual files upon upload to S3.
    #
    # @param [Integer, String] attachment_id Either a number or a string describing the file,
    # e.g., 'Social Security card'
    #
    # @return [Hash] modified metadata object
    def metadata_for_s3(attachment_id)
      key = attachment_id.is_a?(Integer) ? 'claim_id' : 'attachment_id'
      @metadata.except('primaryContactInfo', 'attachment_ids').merge({ key => attachment_id.to_s })
    end

    ##
    # Inserts a record of a particular file and its S3 upload status to the IVC database.
    # The record may later be asyncronously updated via the PEGA callback API.
    #
    # @param [String] file_name Name of file, e.g.,
    # XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXXX_vha_10_10d_supporting_doc-0.pdf
    # @param [String] response_status Stringified array containing an HTTP status code and an optional error
    # message string.
    #
    # @return [IvcChampvaForm]
    def insert_form(file_name, response_status)
      pega_status = response_status.first == 200 ? 'Submitted' : nil
      IvcChampvaForm.create!(
        form_uuid: @metadata['uuid'],
        email: validate_email(@metadata&.dig('primaryContactInfo', 'email')),
        first_name: @metadata&.dig('primaryContactInfo', 'name', 'first'),
        last_name: @metadata&.dig('primaryContactInfo', 'name', 'last'),
        form_number: @metadata['docType'],
        file_name: file_name,
        s3_status: response_status,
        pega_status:
      )

      if Flipper.enabled?(:champva_enhanced_monitor_logging, @current_user)
        monitor.track_insert_form(@metadata['uuid'], @form_id)
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Database Insertion Error for #{@metadata['uuid']}: #{e.message}")
    end

    ##
    # Creates metadata JSON for submitted files from class instance metadata. This metadata JSON
    # is what the downstream PEGA service uses to trigger a lambda job that ingests the uploads.
    # See IvcChampva::VHA1010d.metadata for an example of metadata.
    #
    # @return [Array<Integer, String, nil>] a two-item list containing an HTTP response code and an error or nil. e.g.,
    # [200, nil]
    # [400, '... No such file or directory ...']
    # [500, 'Unexpected response from S3 upload']
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

    ##
    # Uploads a file to the S3 bucket configured in IvcChampva::FileUploader.client
    #
    # @param [String] file_name Name of file to be uploaded
    # @param [String] file_path Path of file to be uploaded
    # @param [Hash] metadata Optional file metadata hash to be associated with the file in S3
    #
    # @return [Array<Integer, String>] List containing either a single HTTP response code or a reponse
    # code and an error message.
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

    ##
    # Provides or creates current instance method S3 client
    #
    # @return [IvcChampva::S3]
    def client
      @client ||= IvcChampva::S3.new(
        region: Settings.ivc_forms.s3.region,
        bucket: Settings.ivc_forms.s3.bucket
      )
    end

    ##
    # Checks provided email against a regex to determine if it is valid, returning nil if not.
    #
    # @param [String] email An email address to validate
    #
    # @return [String, nil] Email is returned if valid, else nil is returned
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
