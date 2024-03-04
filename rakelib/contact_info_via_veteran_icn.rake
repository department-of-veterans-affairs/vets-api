# frozen_string_literal: true

namespace :veteran_contact_info do
  desc 'Build a CSV with contact information for a batch of veteran icns'
  task :build_contact_info_csv, %i[csv_filename icn_list] => :environment do |_, args|
    def build_address(mpi_address)
      line1 = mpi_address.street
      line2 = mpi_address.street2
      street = line1
      street += ", #{line2}" if line2.present?
      city = mpi_address.city
      postal_code = mpi_address.postal_code
      country = mpi_address.country

      "#{street}, #{city} #{postal_code}, #{country}"
    end

    def build_common_name(mpi_profile)
      first_name = mpi_profile.given_names[0]
      middle_name = mpi_profile.given_names[1]
      last_name = mpi_profile.family_name
      suffix = mpi_profile.suffix

      [first_name, middle_name, last_name, suffix].compact.join(' ')
    end

    def retrieve_current_email(vet360_profile)
      current_emails = vet360_profile.emails.select { |email| email.effective_end_date.nil? }

      raise 'All emails expired!' if current_emails.length.zero?

      current_emails.first.email_address
    end

    def upload_to_s3(_csv, csv_filename, csv_path, url_life_length: 1.week.to_i)
      s3_settings = Settings.decision_review.s3

      begin
        s3_bucket = s3_settings.bucket
        Rails.logger.info('Uploading contact info CSV to S3...')
        s3_resource = Aws::S3::Resource.new(
          region: s3_settings.region,
          access_key_id: s3_settings.access_key_id,
          secret_access_key: s3_settings.secret_access_key
        )

        obj = s3_resource.bucket(s3_bucket).object(csv_filename)
        obj.upload_file(csv_path, content_type: 'text/csv')
        obj.presigned_url(:get, expires_in: url_life_length)
      rescue => e
        Rails.logger.error({
                             message: "Error while attempting to upload contact info CSV to S3: #{e.message}",
                             backtrace: e&.backtrace
                           })
      end
    end

    def get_data(icn)
      mpi_service = MPI::Service.new
      mpi_profile = mpi_service.find_profile_by_identifier(identifier: icn, identifier_type: 'ICN')&.profile
      raise 'No mpi profile!' if mpi_profile.nil?

      mpi_address = mpi_profile.address
      raise 'No address in mpi profile!' if mpi_address.nil?

      address = build_address(mpi_address)

      vet360_profile = VAProfile::ContactInformation::Service.get_person(mpi_profile.vet360_id.to_s)&.person

      raise 'No vet360 profile!' if vet360_profile.nil?

      email = retrieve_current_email(vet360_profile)
      common_name = build_common_name(mpi_profile)
      bgs_external_key = (common_name.presence || email).first(39)
      bgs_service = BGS::Services.new(external_uid: icn, external_key: bgs_external_key)
      participant_id = mpi_profile.participant_id
      ssn = mpi_profile.ssn
      # Disabling because `find_by_ssn` is a custom defined method
      # rubocop:disable Rails/DynamicFindBy
      bgs_person = bgs_service.people.find_person_by_ptcpnt_id(participant_id) || bgs_service.people.find_by_ssn(ssn)
      # rubocop:enable Rails/DynamicFindBy
      raise 'No BGS person record found!' unless bgs_person

      file_number = bgs_person[:file_nbr]
      raise 'No file number!' unless file_number

      file_number = file_number.delete('-') if file_number =~ /\A\d{3}-\d{2}-\d{4}\z/

      [icn, file_number, email, address]
    end

    icn_list = args[:icn_list].split
    csv_filename = args[:csv_filename]
    csv_path = "tmp/#{csv_filename}"
    contact_info_csv = CSV.open(csv_path, 'wb') do |csv|
      icn_list.each do |icn|
        user_account_id = UserAccount.find_by(icn:).id
        Rails.logger.info({ message: 'Retrieving contact information for veteran...', user_account_id: })
        contact_data = get_data(icn)

        csv << contact_data
      rescue => e
        Rails.logger.error({
                             message: "Error while attempting to retrieve veteran contact information: #{e.message}",
                             user_account_id:,
                             backtrace: e&.backtrace
                           })
      end
      csv
    end

    upload_to_s3(contact_info_csv, csv_filename, csv_path)
  end
end
