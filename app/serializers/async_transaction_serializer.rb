# frozen_string_literal: true

class AsyncTransactionSerializer < ActiveModel::Serializer
  
  attribute :transaction_id
  attribute :transaction_status

  def id
    nil
  end

end
