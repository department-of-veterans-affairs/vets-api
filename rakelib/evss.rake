# frozen_string_literal: true

desc 'retry failed evss jobs'
task evss_retry_jobs: :environment do
  RELEASE_TIME = Time.zone.parse('2017-09-20T21:59:58.486Z')
  ERROR_CLASS = 'Aws::S3::Errors::NoSuchKey'

  Sidekiq::DeadSet.new.each do |job|
    if job.klass == 'EVSS::DocumentUpload'
      created_at = DateTime.strptime(job['created_at'].to_s, '%s')

      if created_at >= RELEASE_TIME && job['error_class'] == ERROR_CLASS
        EVSS::DocumentUpload.perform_async(*job.args)
        job.delete
      end
    end
  end
end

namespace :evss do
  desc 'export GIBS not found users, usage: rake evss:export_gibs_not_found[/export/path.csv]'
  task :export_gibs_not_found, [:csv_path] => [:environment] do |_, args|
    raise 'No CSV path provided' unless args[:csv_path]
    CSV.open(args[:csv_path], 'wb') do |csv|
      csv << %w[edipi first_name last_name ssn dob created_at]
      GibsNotFoundUser.find_each do |user|
        csv << [
          user.edipi,
          user.first_name,
          user.last_name,
          user.ssn,
          user.dob.strftime('%Y-%m-%d'),
          user.created_at.iso8601
        ]
      end
    end
  end

  desc 'export EDIPIs users with invalid addresss, usage: rake evss:export_invalid_address_edipis[/export/path.csv]'
  task :export_invalid_address_edipis, [:csv_path] => [:environment] do |_, args|
    raise 'No CSV path provided' unless args[:csv_path]
    CSV.open(args[:csv_path], 'wb') do |csv|
      csv << %w[edipi created_at]
      InvalidLetterAddressEdipi.find_each do |i|
        csv << [
          i.edipi,
          i.created_at.iso8601
        ]
      end
    end
  end

  desc 'imports DoD facilities into base_facilities table'
  task :import_dod_facilities => :environment do
    path = File.join(Rails.root, 'rakelib', 'support', 'files', 'dod_facilities.csv')
    CSV.foreach(path, headers: true) do |row|
      address = {
        physical: {
          zip: nil,
          city: row['city'],
          state: row['state'],
          country: row['country']
        }
      }.to_json
      id = SecureRandom.uuid
      Facilities::DODFacility.where(name: row['name'], address: address).first_or_create(
        id: id, name: row['name'], address: address, lat: 0.0, long: 0.0
      )
    end
  end
end
