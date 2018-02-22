# frozen_string_literal: true

class ProcessFileJob
  include Sidekiq::Worker

  def perform(processing_class, store_dir, filename)
    uploader = processing_class.constantize.new(store_dir, filename)
    uploader.retrieve_from_store!(filename)
    old_file = uploader.file
    uploader.store!(old_file)
    old_file.delete
  end
end
