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

    def get_data(icn)
      mpi_service = MPI::Service.new
      mpi_profile = mpi_service.find_profile_by_identifier(identifier: icn, identifier_type: 'ICN')&.profile
      raise 'No mpi profile!' if mpi_profile.nil?

      mpi_address = mpi_profile.address
      raise 'No address in mpi profile!' if mpi_address.nil?

      address = build_address(mpi_address)

      vet360_profile = VAProfile::ContactInformation::Service.get_person(mpi_profile.vet360_id.to_s)&.person

      raise 'No vet360 profile!' if vet360_profile.nil? # do we want to alternatively grab their login email?

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
    CSV.open(csv_filename, 'wb') do |csv|
      icn_list.each do |icn|
        Rails.logger.info({ message: 'Retrieving contact information for veteran...', icn: })
        contact_data = get_data(icn)

        csv << contact_data
      rescue => e
        Rails.logger.error({
                             message: "Error while attempting to retrieve veteran contact information: #{e.message}",
                             veteran_icn: icn,
                             backtrace: e&.backtrace
                           })
      end
    end
  end
end
