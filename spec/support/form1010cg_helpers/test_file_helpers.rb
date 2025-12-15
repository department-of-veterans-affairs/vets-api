# frozen_string_literal: true

module Form1010cgHelpers
  module TestFileHelpers
    # Creates a process-isolated copy of a fixture file for testing
    # @param file_fixture_path [String] Path relative to spec/fixtures/files/
    # @param content_type [String] MIME type for the uploaded file
    # @return [Rack::Test::UploadedFile] File upload object
    def self.create_test_uploaded_file(file_fixture_path, content_type)
      # Create unique identifier per process/test
      process_id = ENV['TEST_ENV_NUMBER'].presence || SecureRandom.hex(4)
      source_path = Rails.root.join('spec', 'fixtures', 'files', file_fixture_path)

      # Create process-specific temp directory
      temp_dir = Rails.root.join('tmp', 'test_uploads', "process_#{process_id}")
      FileUtils.mkdir_p(temp_dir)

      # Copy fixture to process-specific directory with original filename
      temp_file_path = temp_dir.join(file_fixture_path)
      FileUtils.copy_file(source_path, temp_file_path)

      Rack::Test::UploadedFile.new(temp_file_path.to_s, content_type)
    end
  end
end
