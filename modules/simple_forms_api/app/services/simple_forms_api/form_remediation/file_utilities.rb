# frozen_string_literal: true

require 'simple_forms_api/form_remediation/configuration/base'

module SimpleFormsApi
  module FormRemediation
    module FileUtilities
      def zip_directory!(parent_dir, temp_dir, unique_filename)
        raise "Directory not found: #{temp_dir}" unless File.directory?(temp_dir)

        s3_dir = build_path(:dir, parent_dir, 'remediation')
        s3_file_path = build_path(:file, s3_dir, unique_filename, ext: '.zip')
        zip_file_path = build_local_path_from_s3(s3_dir, s3_file_path, temp_dir)

        Zip::File.open(zip_file_path, Zip::File::CREATE) do |zipfile|
          Dir.chdir(temp_dir) do
            Dir['**', '*'].uniq.each do |file|
              next if File.directory?(file)

              zipfile.add(file, File.join(temp_dir, file)) if File.file?(file)
            end
          end
        end

        zip_file_path
      rescue => e
        handle_error("Failed to zip temp directory: #{temp_dir} to location: #{zip_file_path}", e)
      end

      def cleanup(path)
        FileUtils.rm_rf(path)
      end

      def create_temp_directory!(dir_path)
        FileUtils.mkdir_p(dir_path)
      end

      def build_local_path_from_s3(s3_dir, s3_key, local_dir)
        s3_dir = s3_dir.sub(%r{^/}, '') if s3_dir.start_with?('/')
        s3_key = s3_key.sub(%r{^/}, '') if s3_key.start_with?('/')

        local_file_path = Pathname.new(s3_key).relative_path_from(Pathname.new(s3_dir))
        final_path = Pathname.new(local_dir).join(local_file_path)

        create_temp_directory!(final_path.dirname)
        final_path.to_s
      rescue => e
        config.handle_error("Error building local path from S3: #{e.message}", e)
      end

      def build_path(path_type, base_dir, *, ext: '.pdf')
        file_ext = path_type == :file ? ext : ''
        path = Pathname.new(base_dir.to_s).join(*)
        path = path.to_s + file_ext unless file_ext.empty?
        path.to_s
      end

      def write_file(dir_path, file_name, payload)
        File.write(File.join(dir_path, file_name), payload)
      end

      def unique_file_path(form_number, id)
        [Time.zone.today.strftime('%-m.%d.%y'), 'form', form_number, 'vagov', id].join('_')
      end

      def dated_directory_name(form_number)
        "#{Time.zone.today.strftime('%-m.%d.%y')}-Form#{form_number}"
      end

      def write_manifest(row, new_manifest, path)
        id = row[2]
        CSV.open(path, 'ab') do |csv|
          csv << %w[SubmissionDateTime FormType VAGovID VeteranID FirstName LastName] if new_manifest
          csv << row
        end
      rescue => e
        handle_error("Failed writing manifest for submission: #{id}", e)
      end

      private

      def handle_error(*, **)
        config = Configuration::Base.new
        config.handle_error(*, **)
      end
    end
  end
end
