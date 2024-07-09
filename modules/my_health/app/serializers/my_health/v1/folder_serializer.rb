# frozen_string_literal: true

module MyHealth
  module V1
    class FolderSerializer
      include JSONAPI::Serializer

      set_type :folders
      attributes :name, :count, :unread_count, :system_folder

      attribute :folder_id, &:id

      link :self do |object|
        MyHealth::UrlHelper.new.v1_folder_url(object.id)
      end
    end
  end
end
