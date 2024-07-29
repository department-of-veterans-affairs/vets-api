# frozen_string_literal: true

module RepresentationManagement
  class User < ApplicationRecord
    has_kms_key
    has_encrypted :first_name, :last_name, :ssn, :street, :city, :state, :postal_code, key: :kms_key, **lockbox_options
    blind_index :first_name, :last_name, :ssn, :street, :city, :state, :postal_code
  end
end
