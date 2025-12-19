# frozen_string_literal: true

module Common
  module FileHelpers
    module_function

    def delete_file_if_exists(path)
      File.delete(path) if path && File.exist?(path)
    end

    def random_file_path(file_ext = '')
      "tmp/#{SecureRandom.hex}#{file_ext}"
    end

    def generate_random_file(file_body, file_ext = '')
      file_path = random_file_path(file_ext)

      File.binwrite(file_path, file_body)

      file_path
    end

    def generate_clamav_temp_file(file_body, file_name = nil)
      file_name = SecureRandom.hex if file_name.nil?
      clamav_directory = Rails.root.join('clamav_tmp')

      # Create the directory if it doesn't exist
      FileUtils.mkdir_p(clamav_directory)
      file_path = "clamav_tmp/#{file_name}"

      raise 'Cannot write to temporary directory. Check permissions.' unless File.writable?(clamav_directory)

      File.binwrite(file_path, file_body)

      raise "Failed to create temp file at #{file_name}" unless File.exist?(file_path)

      file_path
    end
  end
end
