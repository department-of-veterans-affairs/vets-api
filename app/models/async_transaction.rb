# frozen_string_literal: true

class AsyncTransaction < ActiveRecord::Base
  validates :user_uuid, :source_id, :source_type, :status, :transaction_id, presence: true
end

class AddressTransaction < AsyncTransaction; end
class EmailTransaction < AsyncTransaction; end
class TelephoneTransaction < AsyncTransaction; end
