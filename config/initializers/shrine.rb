# frozen_string_literal: true

require 'shrine'
require 'shrine/storage/file_system'

Rails.application.reloader.to_prepare do
  Shrine.storages = {
    cache: Shrine::Storage::FileSystem.new('tmp', prefix: 'uploads/cache'), # temporary. could be ebs?
    store: Shrine::Storage::FileSystem.new('tmp', prefix: 'uploads/store') # permanent
  }

  Shrine.plugin :determine_mime_type
end
