# frozen_string_literal: true

namespace :persistent_attachment_remediation do
  desc 'Remediate a SavedClaim and its attachments by claim id. Deletes the SavedClaim when bad attachments are found.'
  task :run, [:claim_id] => :environment do |_, args|
    claim_id = args[:claim_id]
    unless claim_id
      puts 'Usage: rake persistent_attachment_remediation:run[CLAIM_ID]'
      exit 1
    end

    claim = SavedClaim.find(claim_id)
    unless claim
      puts "SavedClaim with id #{claim_id} not found."
      exit 1
    end

    # If the claim is a type-casted STI base class, try the module-specific classes
    if claim && ['SavedClaim::Burial', 'SavedClaim::Pensions'].include?(claim.type)
      type_map = {
        'SavedClaim::Burial' => Burials::SavedClaim,
        'SavedClaim::Pensions' => Pensions::SavedClaim
      }
      claim = claim.becomes(type_map[claim.type])
    end

    # Gather expected attachment GUIDs from the claim's form data
    expected_guids = []
    if claim.respond_to?(:attachment_keys) && claim.respond_to?(:open_struct_form)
      expected_guids = claim.attachment_keys.flat_map do |key|
        Array(claim.open_struct_form.send(key)).map { |att| att.try(:confirmationCode) }
      end.compact
    end

    # Find all PersistentAttachments for those GUIDs
    attachments = PersistentAttachment.where(guid: expected_guids)
    delete_claim = false

    attachments.each do |attachment|
      # Test decryption by accessing the file_data
      begin
        attachment.file_data # triggers decryption
      rescue => e
        puts "Attachment #{attachment.id} failed to decrypt: #{e.class}"
        attachment.destroy!
        delete_claim = true
        break
      end

      # Check if saved_claim_id is nil
      if attachment.saved_claim_id.nil?
        puts "Attachment #{attachment.id} has nil saved_claim_id."
        attachment.destroy!
        delete_claim = true
        break
      end
    end

    if delete_claim
      puts "Deleting SavedClaim #{claim.id} and its attachments."
      claim.destroy!
    else
      puts "All attachments for SavedClaim #{claim.id} are valid and decryptable."
    end
  end
end
