# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def self.lockbox_options
    {
      previous_versions: [
        { padding: false },
        { padding: false, master_key: Settings.lockbox.master_key }
      ]
    }
  end

  def self.descendants_using_encryption
    Rails.application.eager_load!
    ApplicationRecord.descendants.select do |model|
      model = model.name.constantize
      model.descendants.empty? &&
        model.respond_to?(:lockbox_attributes) &&
        model.lockbox_attributes.any?
    end
  end

  def timestamp_attributes_for_update_in_model
    kms_key_changed = changed? && changed.include?('encrypted_kms_key')
    called_from_kms_encrypted = caller_locations(1, 1)[0].label == 'encrypt_kms_keys'

    # If update is due to kms key, don't update updated_at
    kms_key_changed || called_from_kms_encrypted ? [] : super
  end
end
