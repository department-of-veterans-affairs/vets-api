# frozen_string_literal: true

require 'common/models/base'

# Folder model
class Folder < Common::Base
  include ActiveModel::Validations
  include RedisCaching

  redis_config REDIS_CONFIG[:secure_messaging_store]

  attribute :id, Integer
  attribute :name, String
  attribute :count, Integer
  attribute :unread_count, Integer
  attribute :system_folder, Boolean

  validates :name, presence: true, folder_name_convention: true, length: { maximum: 50 }

  alias system_folder? system_folder

  def <=>(other)
    name <=> other.name
  end
end
