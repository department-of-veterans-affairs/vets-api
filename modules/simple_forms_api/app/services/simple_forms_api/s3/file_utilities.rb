# frozen_string_literal: true

module SimpleFormsApi
  module S3
    class FileUtilities
      class << self
        def zip_directory!(dir_path)
          raise "Directory not found: #{dir_path}" unless File.directory?(dir_path)

          Zip::File.open(local_upload_file_path, Zip::File::CREATE) do |zipfile|
            Dir.chdir(dir_path) do
              Dir['**', '*'].each do |file|
                next if File.directory?(file)

                zipfile.add(file, File.join(dir_path, file)) if File.file?(file)
              end
            end
          end

          local_upload_file_path
        rescue => e
          handle_error("Failed to zip temp directory: #{dir_path} to location: #{local_upload_file_path}", e)
        end

        def cleanup
          FileUtils.rm_rf(local_upload_file_path)
        end

        def create_temp_directory!(dir_path)
          FileUtils.mkdir_p(dir_path)
        end

        def build_local_file_dir!(s3_key, dir_path)
          local_path = Pathname.new(s3_key).relative_path_from(Pathname.new(s3_directory_path))
          final_path = Pathname.new(dir_path).join(local_path)

          FileUtils.mkdir_p(final_path.dirname)
          final_path.to_s
        end

        def local_upload_file_path
          build_local_file_dir!(s3_upload_file_path)
        end

        def build_path(base_dir, *, type:, is_file: true)
          file_ext = type == :submission ? '.pdf' : '.zip'
          ext = is_file ? file_ext : ''
          path = Pathname.new(base_dir.to_s).join(*).sub_ext(ext)
          path.to_s
        end

        def write_file(dir_path, file_name, payload)
          File.write(File.join(dir_path, file_name), payload)
        end

        def unique_file_path(form_number, id)
          [Time.zone.today.strftime('%-m.%d.%y'), 'form', form_number, 'vagov', id].join('_')
        end

        private

        def handle_error(*, **)
          config = SimpleFormsApi::FormSubmissionRemediation::Configuration::Base.new
          config.handle_error(*, **)
        end
      end
    end
  end
end
