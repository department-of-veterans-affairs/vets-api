# frozen_string_literal: true

class Form214192Validator < ActiveModel::Validator
  def validate(record)
    validate_veteran_information(record)
    validate_employment_information(record)
  end

  private

  def validate_veteran_information(record)
    form_data = record.parsed_form
    return unless form_data

    veteran = form_data['veteran_information']

    if veteran.blank?
      record.errors.add(:form, 'Veteran information is required')
      return
    end

    # Validate required name fields
    validate_required_field(record, veteran, 'full_name', 'Veteran full name is required')
    validate_required_field(record, veteran, 'date_of_birth', 'Veteran date of birth is required')

    # Validate SSN or VA file number (either required)
    unless veteran['ssn'].present? || veteran['va_file_number'].present?
      record.errors.add(:form, 'Either SSN or VA file number is required for veteran')
    end
  end

  def validate_employment_information(record)
    form_data = record.parsed_form
    return unless form_data

    employment = form_data['employment_information']

    if employment.blank?
      record.errors.add(:form, 'Employment information is required')
      return
    end

    # Validate employer fields
    required_employer_fields = %w[employer_name employer_address employer_email]
    required_employer_fields.each do |field|
      validate_required_field(record, employment, field, "#{field} is required")
    end

    # Validate employment detail fields
    required_employment_fields = %w[type_of_work_performed beginning_date_of_employment]
    required_employment_fields.each do |field|
      validate_required_field(record, employment, field, "#{field} is required")
    end
  end

  def validate_required_field(record, data, field, error_message)
    record.errors.add(:form, error_message) if data[field].blank?
  end
end
