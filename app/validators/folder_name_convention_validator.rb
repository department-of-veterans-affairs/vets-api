# frozen_string_literal: true

class FolderNameConventionValidator < ActiveModel::EachValidator
  def validate_each(record, field, value)
    unless value.nil?
      record.errors[field] << 'is not alphanumeric (letters, numbers, or spaces)' unless value =~ /^[[:alnum:]\s]+$/
      record.errors[field] << 'contains illegal characters' if value =~ /[\n\t\f\b\r]/
      record.errors[field] << 'contains illegal characters' unless value.ascii_only?
    end
  end
end
