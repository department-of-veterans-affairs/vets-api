# frozen_string_literal: true

# A script designed to help with migrating the encryption context of the pensions saved claims.
# Please see ../adr/0008-update-the-kms-context.md for more context.
module MigrateClaimsScript
  # Define the old and new encryption contexts
  OLD_CONTEXT_PROC = proc do |record|
    {
      model_name: 'Pensions::SavedClaim',
      model_id: record.id
    }
  end

  NEW_CONTEXT_PROC = proc do |record|
    {
      model_name: 'SavedClaim::Pension',
      model_id: record.id
    }
  end

  ##
  # Temporarily override the kms_encryption_context method of a record
  # @param [ActiveRecord::Base] record the record to override the method for
  # @param [Proc] context_proc the proc defining the encryption context
  #
  # @yield Block of code to execute with the overridden method
  #
  def self.with_kms_encryption_context(record, context_proc)
    original_method = record.method(:kms_encryption_context)
    record.define_singleton_method(:kms_encryption_context) do
      context_proc.call(record)
    end
    yield
  ensure
    record.define_singleton_method(:kms_encryption_context, original_method)
  end

  ##
  # Main migration method
  # @param [Array<Integer>] record_ids Array of record IDs to migrate
  #
  def self.migrate_claims(record_ids)
    record_ids.each do |record_id|
      record = SavedClaim::Pension.find_by(id: record_id)
      next unless record # Skip if record not found

      # Use the old context to read the form
      with_kms_encryption_context(record, OLD_CONTEXT_PROC) do
        record.form
      end

      # Re-encrypt using the new context
      with_kms_encryption_context(record, NEW_CONTEXT_PROC) do
        record.rotate_kms_key!
      end

      puts "Record ID #{record.id} migrated successfully."
    rescue KmsEncrypted::DecryptionError => e
      puts "Decryption failed for record ID #{record_id}: #{e.message}"
    rescue => e
      puts "An error occurred for record ID #{record_id}: #{e.message}"
    end
  end

  ##
  # Run the migration process
  #
  def self.run
    # Prompt the user to input record IDs
    puts 'Enter the record IDs to migrate, separated by commas:'
    input = gets.chomp
    record_ids = input.split(',').map(&:strip).map(&:to_i)

    # Migrate the specified claims
    migrate_claims(record_ids)
  end
end

MigrateClaimsScript.run
