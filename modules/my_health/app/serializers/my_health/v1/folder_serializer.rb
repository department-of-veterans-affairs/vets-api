# frozen_string_literal: true

module MyHealth
  module V1
    class FolderSerializer < ActiveModel::Serializer
      # include MyHealth::Engine.routes.url_helpers

      attribute :id

      attribute(:folder_id) { object.id }
      attribute :name
      attribute :count
      attribute :unread_count
      attribute :system_folder

      link(:self) { MyHealth::UrlHelper.new.v1_folder_url(object.id) }
    end
  end
end
