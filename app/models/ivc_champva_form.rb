# frozen_string_literal: true

class IvcChampvaForm < ApplicationRecord
  validates :form_uuid, presence: true

  has_kms_key
  has_encrypted :ves_request_data, key: :kms_key, **lockbox_options
  has_encrypted :first_name, key: migrate: true, :kms_key, **lockbox_options
  has_encrypted :last_name, key: migrate: true, :kms_key, **lockbox_options
  has_encrypted :email, key: migrate: true, :kms_key, **lockbox_options

  blind_index :email
end
