# frozen_string_literal: true
class PreneedsArrayInclusionValidator < ActiveModel::EachValidator
  def validate_each(record, field, value)
    value_array = Array.wrap(value)
    record.errors.add(field, 'must have at least one value') if value_array.empty?

    list = options[:includes_list]
    record.errors.add(field, 'has an invalid value') if value_array.any? { |v| !list.include?(v) }
  end
end
