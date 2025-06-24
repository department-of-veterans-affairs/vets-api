# frozen_string_literal: true

require 'common/hash_helpers'

module Logging
  # Monitor class for cleaning up persistent attachments
  module AttachmentSanitizer
    ##
    # Handles bad attachments for a claim and in-progress form.
    # Iterates over each attachment key, attempts to decrypt attachments,
    # destroys any that cannot be decrypted, and removes their references from the form data.
    # Updates the in-progress form and sends a notification email.
    #
    # @param claim [SavedClaim]
    # @param in_progress_form [InProgressForm]
    def handle_bad_attachments(claim, in_progress_form)
      form_data = JSON.parse(in_progress_form.form_data, object_class: OpenStruct)

      if claim.respond_to?(:attachment_keys) && claim.respond_to?(:open_struct_form)
        claim.attachment_keys.each do |key|
          process_attachments_for_key(claim, key, form_data)
        end
      end

      in_progress_form.update!(form_data: Common::HashHelpers.deep_to_h(form_data).to_json)
      send_email(claim.id, '') # TODO: Need email_type
    rescue => e
      submit_event(
        :error,
        "#{message_prefix} handle bad attachments error",
        "#{claim_stats_key}.handle_bad_attachments_error",
        claim:,
        in_progress_form_id: in_progress_form&.id,
        errors: e.message
      )
    end

    ##
    # Processes attachments for a given key, destroys any attachment that cannot be decrypted,
    # and removes their references from the form_data.
    #
    # @param claim [SavedClaim]
    # @param key [Symbol]
    # @param form_data [OpenStruct]
    def process_attachments_for_key(claim, key, form_data)
      guids = Array(claim.open_struct_form.send(key)).map { |att| att.try(:confirmationCode) }
      attachments = PersistentAttachment.where(guid: guids)

      attachments.each do |attachment|
        attachment.file_data # triggers decryption
      rescue
        attachment.destroy!
        form_key = attachment_key_map[key] || key
        form_data.send(form_key).reject! { |att| att.confirmationCode == attachment.guid }
      end
    end
  end
end
