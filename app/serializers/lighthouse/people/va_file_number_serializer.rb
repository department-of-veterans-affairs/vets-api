# frozen_string_literal: true

class Lighthouse::People::VaFileNumberSerializer < ActiveModel::Serializer
  type :va_file_number

  attribute :va_file_number

  def id
    nil
  end

  def va_file_number
    return object[:file_nbr] if object
  end
end