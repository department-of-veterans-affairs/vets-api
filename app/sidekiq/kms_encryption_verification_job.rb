# frozen_string_literal: true

class KmsEncryptionVerificationJob
  include Sidekiq::Job
  include SentryLogging

  def perform(models = ApplicationRecord.descendants_using_encryption.map(&:name))
    corrupted_records = models.map(&:constantize).flat_map do |model|
      attributes = model.lockbox_attributes.keys
      model.where(verified_decryptable_at: nil).where.not(encrypted_kms_key: nil).in_batches.flat_map do |relation|
        relation.flat_map do |record|
          decryption_verified = true
          decryption_verification = attributes.flat_map do |attribute|
            unless can_decrypt?(record, attribute)
              decryption_verified = false
              record
            end
          end
          decryption_verification.tap do
            # rubocop:disable Rails/SkipsModelValidations
            record.update_column(:verified_decryptable_at, Time.zone.today) if decryption_verified
            # rubocop:enable Rails/SkipsModelValidations
          end
        end
      end
    end.compact
    raise Lockbox::DecryptionError, corrupted_records if corrupted_records.any?
  end

  private

  def can_decrypt?(record, attribute)
    box = KmsEncrypted::Box.new
    decrypted_data_key = box.decrypt(record.encrypted_kms_key,
                                     context: { model_name: record.class.name, model_id: record.id })
    lockbox = Lockbox.new(key: decrypted_data_key, encode: true)
    ciphertext = record.public_send("#{attribute}_ciphertext")
    lockbox.decrypt ciphertext unless ciphertext.nil?
  rescue NoMethodError
    Rails.logger.error("Record with nil attr but has encrypted_kms_key:
                        #{record.class.name} - id: #{record.id} - attribute: #{attribute}")
    false
  rescue Lockbox::DecryptionError
    Rails.logger.error("Record re-encryption unsuccessful model:
                        #{record.class.name} - id: #{record.id} - attribute: #{attribute}")
    false
  else
    true
  end
end
