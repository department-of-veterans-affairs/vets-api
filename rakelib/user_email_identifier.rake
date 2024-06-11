# frozen_string_literal: true

require 'roo'

desc 'Build a CSV of user email identifiers'

namespace :user_email_identifier do
  task :build_csv, %i[uuid_list] => :environment do |_, args|
    xlsx = Roo::Excelx.new(args[:uuid_list])
    xlsx.sheet(0)
    row_count = xlsx.last_row - 1
    puts "[UserEmailIdentifier] Building CSV from #{args[:uuid_list]}, processing #{row_count} rows..."

    CSV.open('./tmp/user_email_identifiers.csv', 'w') do |csv|
      csv << %w[data_type form_type va_gov_submission_created_at va_gov_user_uuid va_gov_credential_email]
      xlsx.each_row_streaming(offset: 1, pad_cells: true) do |row|
        next if row[3].nil? || row[3].cell_value.nil?

        original_columns = row[0..3].map { |cell| cell && cell.cell_value.to_s.strip }
        csp_uuid = original_columns[3]
        type = csp_uuid.scan(/-/).empty? ? 'idme' : 'logingov'
        verification = UserVerification.find_by_type!(type, csp_uuid)
        user_credential_email = verification.user_credential_email.credential_email

        csv << (original_columns + [user_credential_email])
      rescue ActiveRecord::RecordNotFound
        puts "[UserEmailIdentifier] Record not found for #{type}: #{csp_uuid}"
        row << original_columns
      end
    end
    puts '[UserEmailIdentifier] CSV creation successful, file location: tmp/user_email_identifiers.csv'
  end
end
