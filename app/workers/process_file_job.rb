# frozen_string_literal: true

class ProcessFileJob
  include Sidekiq::Worker

  def perform(store_dir, old_filename)
    process_file_uploader = ProcessFileUploader.new(store_dir, old_filename)
    process_file_uploader.retrieve_from_store!(old_filename)
    old_file = process_file_uploader.file
    process_file_uploader.store!(old_file)
    old_file.delete
  end
end
