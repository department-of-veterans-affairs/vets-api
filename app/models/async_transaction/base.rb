# frozen_string_literal: true

module AsyncTransaction

  class Base < ActiveRecord::Base
    validates :user_uuid, :source_id, :source_type, :status, :transaction_id, presence: true
    validates :transaction_id, uniqueness: { scope: :source_id }
  end

end
