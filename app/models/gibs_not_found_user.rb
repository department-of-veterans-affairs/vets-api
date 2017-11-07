class GibsNotFoundUser < ActiveRecord::Base
  attr_encrypted :ssn, key: Settings.db_encryption_key

  validates :edipi, presence: true, uniqueness: true
  validates :first_name, :last_name, :encrypted_ssn, :encrypted_ssn_iv, :dob, presence: true

  def self.log(user)
    create!(
      edipi: user.edipi,
      first_name: user.first_name,
      last_name: user.last_name,
      ssn: user.ssn,
      dob: user.birth_date
    )
  end
end
