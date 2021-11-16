# frozen_string_literal: true

class PciuAddressLineValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    unless value =~ %r{\A[-a-zA-Z0-9 "#%&'()+,./:@]+\z} || value.blank?
      record.errors.add(attribute, "must only contain letters, numbers, and the special characters #%&'()+,./:@')")
    end
  end
end
