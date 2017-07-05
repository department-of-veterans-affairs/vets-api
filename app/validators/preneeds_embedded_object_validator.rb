# frozen_string_literal: true
class PreneedsEmbeddedObjectValidator < ActiveModel::EachValidator
  def validate_each(record, field, value)
    messages = Array.wrap(value).each_with_object([]) do |v, o|
      o << v.errors.full_messages.join(', ') if v.invalid?
    end

    record.errors.add(field, messages.join(', ')) if messages.present?
  end
end
