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
  attr_reader :mhv_icn, :edipi, :gender, :authn_context

  def ssn=(new_ssn)
    super(new_ssn&.gsub(/\D/, ''))
  end

  def uuid
    SecureRandom.uuid
  end
end
