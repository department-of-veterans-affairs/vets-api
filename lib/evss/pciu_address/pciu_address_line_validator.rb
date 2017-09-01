# frozen_string_literal: true

class PciuAddressLineValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    unless value =~ %r(^[-a-zA-Z0-9 \"#%&'()+,.\/:@]{1,20}$) || value.blank?
      record.errors[attribute] << "must match ^[-a-zA-Z0-9 \"#%&'()+,.\/:@]{1,20}$')"
    end
  end
end
