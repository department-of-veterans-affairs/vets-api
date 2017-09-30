# frozen_string_literal: true

class PciuAddressLineValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    unless value =~ %r(\A[-a-zA-Z0-9 \"#%&'()+,.\/:@]{1,20}\z) || value.blank?
      record.errors[attribute] << "must match \A[-a-zA-Z0-9 \"#%&'()+,.\/:@]{1,20}\z')"
    end
  end
end
