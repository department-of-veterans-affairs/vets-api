# frozen_string_literal: true

module Common
  module FileHelpers
    module_function

    def delete_file_if_exists(path)
      File.delete(path) if File.exist?(path)
    end

    def random_file_path
      "tmp/#{SecureRandom.hex}"
    end

    def generate_temp_file(file_body, file_name = nil)
      file_name = SecureRandom.hex if file_name.nil?
      file_path = "tmp/#{file_name}"

      File.open(file_path, 'wb') do |file|
        file.write(file_body)
      end

      file_path
    end
  end
end
