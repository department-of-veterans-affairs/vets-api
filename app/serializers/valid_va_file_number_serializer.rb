# frozen_string_literal: true

class ValidVAFileNumberSerializer
  include JSONAPI::Serializer

  set_id { '' }
  set_type :valid_va_file_number

  attribute :valid_va_file_number do |object|
    # Settings default is false, override in local to a 'true' value to bypass
    object[:file_nbr] || Settings.valid_va_file_number
  end
end
