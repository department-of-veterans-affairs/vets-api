# frozen_string_literal: true

class HCA::UserAttributes
  include ActiveModel::Validations
  include Virtus.model(nullify_blank: true)

  attribute :first_name, String
  attribute :middle_name, String
  attribute :last_name, String
  attribute :birth_date, String
  attribute :ssn, String

  validates(:first_name, :last_name, :birth_date, :ssn, presence: true)

  # These attributes, along with uuid, are required by mpi/service.
  # They can be nil as they're not part of the HCA form
  attr_reader :mhv_icn, :edipi, :gender, :authn_context, :idme_uuid, :logingov_uuid

  def ssn=(new_ssn)
    super(new_ssn&.gsub(/\D/, ''))
  end

  def birth_date=(dob)
    return if dob.blank?

    birth_day = Date.parse(dob)
    invalid_range = birth_day.year < 1900 || birth_day > 18.years.ago.to_date
    raise ArgumentError, 'DOB is out of acceptable range' if invalid_range

    super(dob)
  rescue
    super(nil)
  end

  def uuid
    SecureRandom.uuid
  end
end
