# frozen_string_literal: true

class GibsNotFoundUser < ApplicationRecord
  # :nocov:
  has_kms_key
  has_encrypted :ssn, key: :kms_key, **lockbox_options

  validates :edipi, presence: true, uniqueness: true
  validates :first_name, :last_name, :ssn_ciphertext, :dob, presence: true

  def self.log(user)
    create_with(
      first_name: user.first_name,
      last_name: user.last_name,
      ssn: user.ssn,
      dob: user.birth_date
    ).find_or_create_by(edipi: user.edipi)
  end
  # :nocov:
end
