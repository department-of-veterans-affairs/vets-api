# frozen_string_literal: true

module AsyncTransaction

  class Base < ActiveRecord::Base

    self.table_name = "async_transactions"

    validates :user_uuid, :source_id, :source, :status, :transaction_id, presence: true
    validates :transaction_id, uniqueness: { scope: :source }
  end

end
