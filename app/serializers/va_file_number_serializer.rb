# frozen_string_literal: true

class VaFileNumberSerializer < ActiveModel::Serializer
  type :va_file_number

  attribute :va_file_number

  def id
    nil
  end

  def va_file_number
    object[:file_nbr]
  end
end
