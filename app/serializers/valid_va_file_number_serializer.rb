# frozen_string_literal: true

class ValidVaFileNumberSerializer < ActiveModel::Serializer
  type :valid_va_file_number

  attribute :valid_va_file_number

  def id
    nil
  end

  def valid_va_file_number
    object[:file_nbr]
  end
end
