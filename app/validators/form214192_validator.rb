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

    veteran = form_data['veteranInformation']

    if veteran.blank?
      record.errors.add(:form, 'Veteran information is required')
      return
    end

    # Validate required name fields
    validate_required_field(record, veteran, 'fullName', 'Veteran full name is required')
    validate_required_field(record, veteran, 'dateOfBirth', 'Veteran date of birth is required')

    # Validate SSN or VA file number (either required)
    unless veteran['ssn'].present? || veteran['vaFileNumber'].present?
      record.errors.add(:form, 'Either SSN or VA file number is required for veteran')
    end
  end

  def validate_employment_information(record)
    form_data = record.parsed_form
    return unless form_data

    employment = form_data['employmentInformation']

    if employment.blank?
      record.errors.add(:form, 'Employment information is required')
      return
    end

    # Validate employer fields
    required_employer_fields = %w[employerName employerAddress employerEmail]
    required_employer_fields.each do |field|
      validate_required_field(record, employment, field, "#{field} is required")
    end

    # Validate employment detail fields
    required_employment_fields = %w[typeOfWorkPerformed beginningDateOfEmployment]
    required_employment_fields.each do |field|
      validate_required_field(record, employment, field, "#{field} is required")
    end
  end

  def validate_required_field(record, data, field, error_message)
    record.errors.add(:form, error_message) if data[field].blank?
  end
end
