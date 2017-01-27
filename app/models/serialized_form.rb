# frozen_string_literal: true
class SerializedForm < ActiveRecord::Base
  attr_encrypted :form_data, key: ENV['DB_ENCRYPTION_KEY']
end
