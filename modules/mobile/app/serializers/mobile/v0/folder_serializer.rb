# frozen_string_literal: true

module Mobile
  module V0
    class FolderSerializer
      include JSONAPI::Serializer

      set_type :folders
      set_id :id

      attributes :name, :count, :unread_count, :system_folder

      attribute :folder_id, &:id

      link :self do |object|
        Mobile::UrlHelper.new.v0_folder_url(object.id)
      end
    end
  end
end
