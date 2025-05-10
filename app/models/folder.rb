# frozen_string_literal: true

require 'vets/model'

# Folder model
class Folder
  include Vets::Model
  include RedisCaching

  redis_config REDIS_CONFIG[:secure_messaging_store]

  attribute :id, Integer
  attribute :name, String
  attribute :count, Integer
  attribute :unread_count, Integer
  attribute :system_folder, Bool, default: false
  attribute :metadata, Hash, default: {} # rubocop:disable Rails/AttributeDefaultBlockValue

  validates :name, presence: true, folder_name_convention: true, length: { maximum: 50 }

  alias system_folder? system_folder

  default_sort_by name: :asc
end
