# frozen_string_literal: true

class IvcChampvaForm < ApplicationRecord
  validates :form_uuid, presence: true

  has_kms_key
  has_encrypted :ves_request_data, key: :kms_key, **lockbox_options
  has_encrypted :first_name, migrating: true, key: :kms_key, **lockbox_options
  has_encrypted :last_name, migrating: true, key: :kms_key, **lockbox_options
  has_encrypted :email, migrating: true, key: :kms_key, **lockbox_options
end
