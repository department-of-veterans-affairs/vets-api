# frozen_string_literal: true

require 'common/hash_helpers'
require 'logging/monitor'

module PersistentAttachments
  ##
  # Sanitizes attachments for claims and in-progress forms.
  # This module provides methods to handle bad attachments by decrypting them,
  # destroying those that cannot be decrypted, and updating the form data accordingly.
  class Sanitizer
    ##
    # Handles bad attachments for a claim and in-progress form.
    # Iterates over each attachment key, attempts to decrypt attachments,
    # destroys any that cannot be decrypted, and removes their references from the form data.
    # Updates the in-progress form and sends a notification email.
    #
    # @param claim [SavedClaim]
    # @param in_progress_form [InProgressForm]
    def sanitize_attachments(claim, in_progress_form)
      form_data = JSON.parse(in_progress_form.form_data, object_class: OpenStruct)

      if claim.respond_to?(:attachment_keys) && claim.respond_to?(:open_struct_form)
        claim.attachment_keys.each do |key|
          process_attachments_for_key(claim, key, form_data)
        end
      end

      in_progress_form.update!(form_data: Common::HashHelpers.deep_to_h(form_data).to_json)
    rescue => e
      additional_context = { claim:, in_progress_form_id: in_progress_form&.id, errors: claim&.errors&.errors,
                             error: e&.message }
      Logging::Monitor.new('vets-api-service').track_request(
        :error,
        'PersistentAttachments::Sanitizer sanitize attachments error',
        'api.persistent_attachments.sanitize_attachments_error',
        call_location: caller_locations.first,
        **additional_context
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
      guids = Array(claim.open_struct_form.send(key)).map do |att|
        att.try(:confirmationCode) || att.try(:confirmation_code)
      end
      attachments = PersistentAttachment.where(guid: guids)

      attachments.each do |attachment|
        attachment.file_data # triggers decryption
      rescue
        attachment.destroy!
        form_key = claim.respond_to?(:attachment_key_map) ? (claim.attachment_key_map[key] || key) : key
        form_data.send(form_key).reject! { |att| att.confirmationCode == attachment.guid }
      end
    end
  end
end
