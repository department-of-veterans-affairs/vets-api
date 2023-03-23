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
  desc 'print GIBS not found users in CSV format for last n days with a limit, usage: rake evss:gibs_not_found[7,100]'
  task :gibs_not_found, %i[days limit] => [:environment] do |_, args|
    args.with_defaults(days: 7, limit: 100)
    result = PersonalInformationLog
             .where('created_at >= ?', args[:days].to_i.day.ago)
             .where(error_class: 'EVSS::GiBillStatus::NotFound')
             .limit(args[:limit].to_i)

    result.each_with_index do |r, i|
      user = JSON.parse(r.data['user'])
      puts user.keys.push('created_at').join(',') if i.zero?
      puts user.values.push(r.created_at).join(',')
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

  desc 'export post 911 not found users for the last week, usage: rake evss:export_post_911_not_found[/export/path.csv]'
  task :export_post_911_not_found, [:file_path] => [:environment] do |_, args|
    raise 'No JSON file path provided' unless args[:file_path]

    File.open(args[:file_path], 'w+') do |f|
      PersonalInformationLog.where(error_class: 'EVSS::GiBillStatus::NotFound').last_week.find_each do |error|
        f.puts(error.data.to_json)
      end
    end
  end

  desc 'imports DoD facilities into base_facilities table'
  task import_dod_facilities: :environment do
    path = Rails.root.join('rakelib', 'support', 'files', 'dod_facilities.csv')
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
      Facilities::DODFacility.where(name: row['name'], address:).first_or_create(
        id:, name: row['name'], address:, lat: 0.0, long: 0.0
      )
    end
  end
end
