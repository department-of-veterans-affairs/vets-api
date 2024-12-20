# frozen_string_literal: true

require 'simple_forms_api/form_remediation/configuration/base'

module SimpleFormsApi
  module FormRemediation
    module FileUtilities
      def zip_directory!(parent_dir, temp_dir, unique_filename)
        validate_directory_existence!(temp_dir)
        zip_file_path = prepare_file_paths(parent_dir, temp_dir, unique_filename)

        create_zip_file(zip_file_path, temp_dir)
      rescue => e
        handle_error("Failed to zip directory: #{temp_dir} to #{zip_file_path}", e)
      end

      def prepare_file_paths(parent_dir, temp_dir, unique_filename)
        s3_dir = build_path(:dir, parent_dir, 'remediation')
        s3_file_path = build_path(:file, s3_dir, unique_filename, ext: '.zip')
        build_local_path_from_s3(s3_dir, s3_file_path, temp_dir)
      end

      def validate_directory_existence!(directory)
        raise "Directory not found: #{directory}" unless File.directory?(directory)
      end

      def create_zip_file(zip_file_path, temp_dir)
        Zip::File.open(zip_file_path, Zip::File::CREATE) do |zipfile|
          add_files_to_zip(zipfile, temp_dir)
        end
        zip_file_path
      end

      def add_files_to_zip(zipfile, temp_dir)
        temp_dir_files = Dir.glob(File.join(temp_dir, '**', '*')).uniq
        temp_dir_files.each do |file|
          next unless File.file?(file)

          relative_path = file.sub("#{temp_dir}/", '')
          zipfile.add(relative_path, file)
        end
      end

      def cleanup!(path)
        log_info("Cleaning up path: #{path}")
        FileUtils.rm_rf(path)
      end

      def create_directory!(dir_path)
        return if File.directory?(dir_path)

        FileUtils.mkdir_p(dir_path)
      end

      def build_local_path_from_s3(s3_dir, s3_key, local_dir)
        clean_s3_path!(s3_dir, s3_key)
        local_file_path = Pathname.new(s3_key).relative_path_from(Pathname.new(s3_dir))
        final_path = Pathname.new(local_dir).join(local_file_path)

        create_directory!(final_path.dirname)
        final_path.to_s
      rescue => e
        handle_error('Error building local path from S3', e)
      end

      def clean_s3_path!(*paths)
        paths.each { |path| path.sub!(%r{^/}, '') if path.start_with?('/') }
      end

      def build_path(path_type, base_dir, *path_segments, ext: '.pdf')
        file_ext = path_type == :file ? ext : ''
        path = Pathname.new(base_dir.to_s).join(*path_segments)
        path = path.to_s + file_ext if file_ext.present?
        path.to_s
      end

      def write_file(dir_path, file_name, content)
        File.write(File.join(dir_path, file_name), content)
      end

      def unique_file_name(form_number, id, date = Time.now.utc.to_date)
        "#{date.strftime('%-m.%d.%y')}_form_#{form_number}_vagov_#{id}"
      end

      def dated_directory_name(form_number, date = Time.now.utc.to_date)
        "#{date.strftime('%-m.%d.%y')}-Form#{form_number}"
      end

      def write_manifest(row, path)
        new_manifest = !File.exist?(path)
        CSV.open(path, 'ab') do |csv|
          csv << %w[SubmissionDateTime FormType VAGovID VeteranID FirstName LastName] if new_manifest
          csv << row
        end
      rescue => e
        handle_error('Failed writing manifest for submission', e)
      end

      def log_info(message, **details)
        Rails.logger.info({ message: }.merge(details))
      end

      def log_error(message, error, **details)
        Rails.logger.error({ message:, error: error.message, backtrace: error.backtrace.first(5) }.merge(details))
      end

      def handle_error(message, error, **details)
        log_error(message, error, **details)
        raise error
      end
    end
  end
end
