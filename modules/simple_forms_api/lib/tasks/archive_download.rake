# frozen_string_literal: true

require_relative '../../app/services/simple_forms_api/s3/submission_archive_builder'
require 'common/file_helpers'

namespace :simple_forms_api do
  desc 'Build submission archives for a collection of ' \
       'benefits_intake_uuids, zips them, and downloads ' \
       'them to a specified location'

  task :download_archives, %i[benefits_intake_uuids download_path] => :environment do |_, args|
    benefits_intake_uuids = args[:benefits_intake_uuids].split
    download_path = args[:download_path] || raise('Please provide a download_path')

    if benefits_intake_uuids.empty?
      puts 'No benefits_intake_uuids provided. Please provide a collection of benefits_intake_uuids.'
      exit 1
    end

    benefits_intake_uuids.each do |uuid|
      archive_builder = SimpleFormsApi::S3::SubmissionArchiveBuilder.new(benefits_intake_uuid: uuid)
      archive_dir = archive_builder.run

      zip_file_path = zip_directory(archive_dir)

      scp_transfer(zip_file_path, download_path)

      delete_temp_file(zip_file_path)
    rescue => e
      puts "Error processing benefits_intake_uuid #{uuid}: #{e.message}"
      raise e
    end
  end
end

def zip_directory(dir_path)
  puts "Zipping temporary directory: #{dir_path}"
  zip_file_path = "#{dir_path.chop}.zip"
  system("zip -r #{zip_file_path} #{dir_path}")
  zip_file_path
end

def delete_temp_file(dir_path)
  puts "Deleting temporary directory: #{dir_path}"
  FileUtils.rm_f(dir_path)
end

def scp_transfer(local_dir_path, remote_path)
  puts "Transferring zipped package: #{local_dir_path}"
  # I think these should already be set by the system, but just in case...
  user = ENV['USER'] || ask_for('username')
  remote_host = ENV['REMOTE_HOST'] || ask_for('remote host')

  system("scp #{local_dir_path} #{user}@#{remote_host}:#{remote_path}")
end

def ask_for(info)
  print "Please enter your #{info}: "
  gets.chomp
end
