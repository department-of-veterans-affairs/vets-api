# frozen_string_literal: true

module VBMS
  module Efolder
    class UploadClaimAttachments
      def initialize(claim)
        @claim = claim
        @metadata = generate_metadata
      end

      def upload!
        # ensure we have attachments to process and upload
        unless @claim.persistent_attachments.size > 0
          err_msg = "Claim #{@claim.id} does not contain any supporting documents."
          raise ActiveRecord::RecordNotFound, err_msg
        end

        @claim.persistent_attachments.each do |attachment|
          # uploading to efolder is a two step process. Fetch token and upload.
          token = fetch_upload_token(attachment)
          upload(token, attachment)
        end
      end

      private

      def fetch_upload_token(attachment)
        content_hash = Digest::SHA1.hexdigest(attachment.file.read)
        filename = SecureRandom.uuid + attachment.original_filename
        vbms_request = VBMS::Requests::InitializeUpload.new(
          content_hash: content_hash,
          filename: filename,
          file_number: @metadata['file_number'],
          va_receive_date: @metadata['receive_date'],
          doc_type: @metadata['doc_type'],
          source: @metadata['source'],
          subject: @metadata['source'] + '_' + @metadata['doc_type'], # TODO
          new_mail: true # TODO
        )
        # token = client.send_request(vbms_request)
        token = SecureRandom.uuid # stub for dev
        token
      rescue
        # TODO: handle service outages and invalid attachments
        raise
      end

      def upload(token, attachment)
        upload_request = VBMS::Requests::UploadDocument.new(
          upload_token: token,
          filepath: attachment.file.to_io.path
        )
        # client.send_request(upload_request)
      rescue
        # TODO: handle service outages and upload errors
        raise
      end

      def client
        @client ||= VBMS::Client.from_env_vars(env_name: Settings.vbms.env)
      rescue
        @client = nil
      end

      def generate_metadata
        form = @claim.parsed_form
        veteran_full_name = form['veteranFullName']
        address = form['claimantAddress'] || form['veteranAddress']
        receive_date = @claim.created_at.in_time_zone('Central Time (US & Canada)')
  
        metadata = {
          'first_name' => veteran_full_name['first'],
          'last_name' => veteran_full_name['last'],
          'file_number' => form['vaFileNumber'] || form['veteranSocialSecurityNumber'],
          'receive_date' => receive_date.strftime('%Y-%m-%d %H:%M:%S'),
          'guid' => @claim.guid,
          'zip_code' => address['country'] == 'USA' ? address['postalCode'] : FOREIGN_POSTALCODE,
          'source' => 'va.gov',
          'doc_type' => @claim.form_id
        }
        metadata
      end
    end
  end
end
