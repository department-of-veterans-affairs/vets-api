# frozen_string_literal: true
class FolderSerializer < ActiveModel::Serializer
  def id
    object.folder_id
  end

  attribute :folder_id
  attribute :name
  attribute :count
  attribute :unread_count
  attribute :system_folder

  link(:self) { v0_folder_url(object.folder_id) }
end
