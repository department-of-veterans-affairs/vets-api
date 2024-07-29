# frozen_string_literal: true

class FolderSerializer
  include JSONAPI::Serializer
  singleton_class.include Rails.application.routes.url_helpers

  set_type :folders

  attribute :folder_id, &:id
  attribute :name
  attribute :count
  attribute :unread_count
  attribute :system_folder

  link :self do |object|
    v0_folder_url(object.id)
  end
end
