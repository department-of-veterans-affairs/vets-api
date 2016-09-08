# frozen_string_literal: true
class FolderSerializer < ActiveModel::Serializer
  # Alias id to folder_id to keep consistent with other model naming conventions
  attribute(:folder_id) { object.id }

  attribute :id
  attribute :name
  attribute :count
  attribute :unread_count
  attribute :system_folder
end
