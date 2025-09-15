# frozen_string_literal: true

class IvcChampvaForm < ApplicationRecord
  validates :form_uuid, presence: true

  # Ignore old unencrypted columns during transition period
  self.ignored_columns += %w[first_name last_name email]

  has_kms_key
  has_encrypted :ves_request_data, key: :kms_key, **lockbox_options
  has_encrypted :first_name, key: :kms_key, **lockbox_options
  has_encrypted :last_name, key: :kms_key, **lockbox_options
  has_encrypted :email, key: :kms_key, **lockbox_options

  blind_index :email
end
