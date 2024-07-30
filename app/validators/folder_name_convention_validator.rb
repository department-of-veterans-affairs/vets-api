# frozen_string_literal: true

class FolderNameConventionValidator < ActiveModel::EachValidator
  def validate_each(record, field, value)
    unless value.nil?
      unless value.match?(/^[[:alnum:]\s]+$/)
        record.errors.add(field, 'is not alphanumeric (letters, numbers, or spaces)')
      end
      record.errors.add(field, 'contains illegal characters') if value.match?(/[\n\t\f\b\r]/)
      record.errors.add(field, 'contains illegal characters') unless value.ascii_only?
    end
  end
end
