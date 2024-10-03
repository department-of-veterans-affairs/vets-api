# frozen_string_literal: true

module SimpleFormsApi
  module S3
    module FileUtilities
      def zip_directory!(parent_dir, file_path)
        base_dir = build_path(:dir, parent_dir, 'remediation', ext: '.zip')
        raise "Directory not found: #{base_dir}" unless File.directory?(base_dir)

        Zip::File.open(file_path, Zip::File::CREATE) do |zipfile|
          Dir.chdir(base_dir) do
            Dir['**', '*'].each do |file|
              next if File.directory?(file)

              zipfile.add(file, File.join(base_dir, file)) if File.file?(file)
            end
          end
        end

        file_path
      rescue => e
        handle_error("Failed to zip temp directory: #{base_dir} to location: #{file_path}", e)
      end

      def cleanup(path)
        FileUtils.rm_rf(path)
      end

      def create_temp_directory!(dir_path)
        FileUtils.mkdir_p(dir_path)
      end

      def build_local_file_dir!(s3_key, dir_path, s3_dir_path)
        local_path = Pathname.new(s3_key).relative_path_from(Pathname.new(s3_dir_path))
        final_path = Pathname.new(dir_path).join(local_path)

        FileUtils.mkdir_p(final_path.dirname)
        final_path.to_s
      end

      def build_path(path_type, base_dir, *, ext: '.pdf')
        file_ext = path_type == :file ? ext : ''
        path = Pathname.new(base_dir.to_s).join(*).sub_ext(file_ext)
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
