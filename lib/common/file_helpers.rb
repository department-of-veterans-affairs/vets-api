# frozen_string_literal: true

module Common
  module FileHelpers
    module_function

    def delete_file_if_exists(path)
      File.delete(path) if path && File.exist?(path)
    end

    def random_file_path
      "tmp/#{SecureRandom.hex}"
    end

    def generate_random_file(file_body)
      file_path = random_file_path

      File.binwrite(file_path, file_body)

      file_path
    end

    def generate_clamav_temp_file(file_body, file_name = nil)
      file_name = SecureRandom.hex if file_name.nil?
      clamav_directory = Rails.root.join('clamav_tmp')

      # Create the directory if it doesn't exist
      FileUtils.mkdir_p(clamav_directory)

      file_path = "clamav_tmp/#{file_name}"

      File.binwrite(file_path, file_body)

      file_path
    end
  end
end
