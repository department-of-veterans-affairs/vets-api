# frozen_string_literal: true
class InProgressForm < ActiveRecord::Base
  attr_encrypted :form_data, key: ENV['DB_ENCRYPTION_KEY']
end
