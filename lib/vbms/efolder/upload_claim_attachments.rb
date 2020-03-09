# frozen_string_literal: true

module VBMS
  module Efolder
    class UploadClaimAttachments
      def initialize(claim)
        @claim = claim
        @metadata = generate_metadata
      end

      def upload!
        # ensure this claim has attachments to process
        unless @claim.persistent_attachments.size > 0
          err_msg = "Claim #{@claim.id} does not contain any supporting documents."
          raise ActiveRecord::RecordNotFound, err_msg
        end

        @claim.persistent_attachments.each do |attachment|
          efolder = VBMS::Efolder::Service.new(attachment.file, @metadata)
          efolder.upload_file!
        end
      end

      private

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
