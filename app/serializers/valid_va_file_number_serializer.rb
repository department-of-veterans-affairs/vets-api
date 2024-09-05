# frozen_string_literal: true

class ValidVAFileNumberSerializer
  include JSONAPI::Serializer

  set_id { '' }
  set_type :valid_va_file_number

  attribute :valid_va_file_number do |object|
    object[:file_nbr]
  end
end
