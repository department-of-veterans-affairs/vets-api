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

  def ssn=(new_ssn)
    super(new_ssn.gsub(/\D/, ''))
  end
end
