# frozen_string_literal: true

class FolderSerializer < ActiveModel::Serializer
  attribute :id

  attribute(:folder_id) { object.id }
  attribute :name
  attribute :count
  attribute :unread_count
  attribute :system_folder

  link(:self) { v0_folder_url(object.id) }
end
