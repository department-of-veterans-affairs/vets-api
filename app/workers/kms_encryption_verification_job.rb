# frozen_string_literal: true

class KmsEncryptionVerificationJob
  include Sidekiq::Worker
  include SentryLogging

  def perform(models = ApplicationRecord.descendants_using_encryption.map(&:name))
    corrupted_records = models.map(&:constantize).flat_map do |model|
      attributes = model.lockbox_attributes.keys
      model.where.not(encrypted_kms_key: nil).flat_map do |record|
        attributes.flat_map do |attribute|
          record unless can_decrypt?(record, attribute)
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
    lockbox.decrypt record.public_send("#{attribute}_ciphertext")
  rescue Lockbox::DecryptionError
    Rails.logger.error("Record re-encryption unsuccessful model:
                        #{record.class.name} - id: #{record.id} - attribute: #{attribute}")
    false
  else
    true
  end
end
