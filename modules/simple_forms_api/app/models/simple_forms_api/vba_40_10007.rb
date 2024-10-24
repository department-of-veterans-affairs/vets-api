# frozen_string_literal: true

require 'json'

module SimpleFormsApi
  class VBA4010007 < BaseForm
    STATS_KEY = 'api.simple_forms_api.40_10007'

    def not_veteran?(form_data)
      relationship = form_data.dig('application', 'claimant', 'relationship_to_vet')
      relationship != '1' && relationship != 'veteran'
    end

    def dig_data(form_data, field_veteran, field_claimant)
      not_veteran?(form_data) ? form_data.dig(*field_veteran) : form_data.dig(*field_claimant)
    end

    def veteran_or_claimant_first_name(form_data)
      dig_data(form_data, %w[application veteran current_name first], %w[application claimant name first])
    end

    def veteran_or_claimant_last_name(form_data)
      dig_data(form_data, %w[application veteran current_name last], %w[application claimant name last])
    end

    def veteran_or_claimant_file_number(form_data)
      dig_data(form_data, %w[application veteran ssn], %w[application claimant ssn]) || ''
    end

    def metadata
      {
        'veteranFirstName' => veteran_or_claimant_first_name(@data),
        'veteranLastName' => veteran_or_claimant_last_name(@data),
        'fileNumber' => veteran_or_claimant_file_number(@data)&.gsub('-', ''),
        'zipCode' => @data.dig('application', 'claimant', 'address', 'postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'NCA'
      }
    end

    def zip_code_is_us_based
      # TODO: Implement this
      true
    end

    def service(num, field, date)
      service_records = data.dig('application', 'veteran', 'service_records')

      return '' if service_records.nil? || service_records[num].nil?

      value = if date
                service_records[num][field]&.[](date)
              else
                service_records[num][field]
              end

      value.to_s # Convert nil to an empty string
    end

    def find_cemetery_by_id(cemetery_id)
      file_path = 'modules/simple_forms_api/app/json/cemeteries.json'
      file_content = File.read(file_path)
      cemeteries = JSON.parse(file_content)

      cemetery = cemeteries['data']&.find do |entry|
        entry['attributes']&.dig('cemetery_id') == cemetery_id
      end

      if cemetery
        cemetery['attributes']['name']
      else
        'Cemetery not found.'
      end
    end

    def words_to_remove
      veteran_ssn_and_file_number + veteran_dates_of_birth_and_death + postal_code +
        phone_number + email
    end

    def format_date(date)
      if date == ''
        date
      else
        Date.strptime(date, '%Y-%m-%d').strftime('%m/%d/%Y') #=> "02/25/2012"
      end
    end

    SERVICE_LABELS = {
      'AC' => 'U.S. Army Air Corps',
      'AF' => 'U.S. Air Force',
      'AR' => 'U.S. Army',
      'CG' => 'U.S. Coast Guard',
      'CV' => 'Civilian, Wake Island Naval Air Station',
      'FP' => 'Civilian Ferry Pilot',
      'MM' => 'U.S. Merchant Marine',
      'PH' => 'U.S. Public Health Service',
      'NN' => 'U.S. Navy Nurse Corps',
      'WA' => 'Women’s Army Auxiliary Corps',
      'WS' => 'Women’s Army Corps',
      'CF' => 'Royal Canadian Air Force',
      'RO' => 'Army, Navy, or Air Force ROTC',
      'CA' => 'U.S. Citizen, Served with Allies (WWII)',
      'WR' => 'Women’s Reserve (Navy, Marine Corps, Coast Guard)',
      'CS' => 'Civilian, Strategic Service (OSS)',
      'KC' => 'Quartermaster Corps, Keswick Crew (WWII)',
      'CB' => 'Defense of Bataan (WWII)',
      'CO' => 'U.S. Army Transport Service',
      'CI' => 'Civilian, Identification Friend or Foe (IFF) Technician',
      'CC' => 'U.S. Civilian AFS Volunteer (WWII)',
      'GS' => 'Civilian Crew, U.S. Coast and Geodetic Survey Vessels',
      'FT' => 'American Volunteers Flying Tigers',
      'CE' => 'Royal Canadian Corps of Signals',
      'C2' => 'Civilian Air Transport Command (United)',
      'C3' => 'Civilian Air Transport Command (TWA)',
      'C4' => 'Civilian Air Transport Command (Vultee)',
      'C5' => 'Civilian Air Transport Command (American)',
      'C7' => 'Civilian Air Transport Command (Northwest)',
      'CD' => 'U.S. Navy Transport Service',
      'NM' => 'Non-Military Civilian',
      'AL' => 'Allied Forces',
      'AA' => 'U.S. Army Air Forces',
      'AT' => 'U.S. Army Air Forces (Air Transport Command)',
      'GP' => 'Guam Combat Patrol',
      'MC' => 'U.S. Marine Corps',
      'NA' => 'U.S. Navy',
      'NO' => 'National Oceanic and Atmospheric Admin.',
      'PS' => 'Philippine Scouts',
      'CM' => 'Cadet or Midshipman',
      'WP' => 'Women Air Force Service Pilots',
      'GU' => 'Wake Island Defender (Guam)',
      'MO' => 'U.S Merchant Seamen, Operation Mulberry (WWII)',
      'FS' => 'American Field Service',
      'ES' => 'American Volunteer Guard',
      'FF' => 'Foreign Forces',
      'GC' => 'U.S. Coast and Geodetic Survey',
      'PA' => 'Philippine Army',
      'AG' => 'U.S. Air National Guard',
      'NG' => 'U.S. Army National Guard',
      'PG' => 'Philippine Guerilla',
      'XA' => 'U.S. Navy Reserve',
      'XR' => 'U.S. Army Reserve',
      'XF' => 'U.S. Air Force Reserve',
      'XC' => 'U.S. Marine Corps Reserve',
      'XG' => 'Coast Guard Reserve'
    }.freeze

    def get_service_label(key)
      SERVICE_LABELS[key]
    end

    DISCHARGE_TYPE = {
      '1' => 'Honorable',
      '2' => 'General',
      '3' => 'Entry Level Separation/Uncharacterized',
      '4' => 'Other Than Honorable',
      '5' => 'Bad Conduct',
      '6' => 'Dishonorable',
      '7' => 'Other'
    }.freeze

    def get_discharge_label(key)
      DISCHARGE_TYPE[key]
    end

    RELATIONSHIP_TO_VETS = {
      '1' => 'Is veteran',
      '2' => 'Spouse or surviving spouse',
      '3' => 'Unmarried adult child',
      '4' => 'Other'
    }.freeze

    ETHNICITY_VALUES = {
      'isSpanishHispanicLatino' => 'Hispanic or Latino',
      'notSpanishHispanicLatino' => 'Not Hispanic or Latino',
      'unknown' => 'Unknown',
      'na' => 'Prefer not to answer'
    }.freeze

    MILITARY_STATUS = {
      'A' => 'Active duty',
      'S' => 'Reserve/National Guard',
      'R' => 'Retired',
      'E' => 'Retired active duty',
      'O' => 'Retired Reserve/National Guard',
      'V' => 'Veteran',
      'X' => 'Other',
      'I' => 'Death related to inactive duty training',
      'D' => 'Died on active duty'
    }.freeze

    GENDER = {
      'Male' => 'Male',
      'Female' => 'Female',
      'na' => 'Prefer not to answer'
    }.freeze

    def get_relationship_to_vet(key)
      RELATIONSHIP_TO_VETS[key]
    end

    def get_ethnicity_labels(key)
      ETHNICITY_VALUES[key]
    end

    def get_military_status(key)
      MILITARY_STATUS[key]
    end

    def get_gender(key)
      GENDER[key]
    end

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def create_attachment_page(file_path)
      veteran_sex = get_gender(@data.dig('application', 'veteran', 'gender'))

      race_comment = @data.dig('application', 'veteran', 'race_comment')

      place_of_birth = @data.dig('application', 'veteran', 'place_of_birth')

      city_of_birth = @data.dig('application', 'veteran', 'city_of_birth')

      state_of_birth = @data.dig('application', 'veteran', 'state_of_birth')

      service_branch_value_a = get_service_label(@data.dig('application', 'veteran', 'service_records', 0,
                                                           'service_branch')) || ''
      service_branch_value_b = get_service_label(@data.dig('application', 'veteran', 'service_records', 1,
                                                           'service_branch')) || ''
      service_branch_value_c = get_service_label(@data.dig('application', 'veteran', 'service_records', 2,
                                                           'service_branch')) || ''
      discharge_type_a = get_discharge_label(@data.dig('application', 'veteran', 'service_records', 0,
                                                       'discharge_type')) || ''
      discharge_type_b = get_discharge_label(@data.dig('application', 'veteran', 'service_records', 1,
                                                       'discharge_type')) || ''
      discharge_type_c = get_discharge_label(@data.dig('application', 'veteran', 'service_records', 2,
                                                       'discharge_type')) || ''
      highest_rank_a = @data.dig('application', 'veteran', 'service_records', 0, 'highest_rank_') || ''
      highest_rank_b = @data.dig('application', 'veteran', 'service_records', 1, 'highest_rank') || ''
      highest_rank_c = @data.dig('application', 'veteran', 'service_records', 2, 'highest_rank') || ''
      highest_rank_int_a = @data.dig('application', 'veteran', 'service_records', 0, 'highest_rank_description') || ''
      highest_rank_int_b = @data.dig('application', 'veteran', 'service_records', 1, 'highest_rank_description') || ''
      highest_rank_int_c = @data.dig('application', 'veteran', 'service_records', 2, 'highest_rank_description') || ''

      ethnicity = get_ethnicity_labels(@data.dig('application', 'veteran', 'ethnicity'))
      relationship_to_veteran = @data.dig('application', 'claimant', 'relationship_to_vet')
      sponsor_veteran_email = @data.dig('application', 'veteran', 'email')
      sponsor_veteran_phone = @data.dig('application', 'veteran', 'phone_number')
      sponsor_veteran_maiden = @data.dig('application', 'veteran', 'current_name', 'maiden')
      military_status_label = get_military_status(@data.dig('application', 'veteran', 'military_status'))

      # rubocop:disable Layout/LineLength
      if @data['version']
        race_data = @data.dig('application', 'veteran', 'race')
        race = ''.dup
        race += 'American Indian or Alaskan Native, ' if race_data['is_american_indian_or_alaskan_native']
        race += 'Asian, ' if race_data['is_asian']
        race += 'Black or African American, ' if race_data['is_black_or_african_american']
        race += 'Native Hawaiian or other Pacific Islander, ' if race_data['is_native_hawaiian_or_other_pacific_islander']
        race += 'White, ' if race_data['is_white']
        race += 'Prefer not to answer, ' if race_data['na']
        race += 'Other, ' if race_data['is_other']
        race.chomp!(', ')
      end
      # rubocop:enable Layout/LineLength

      Prawn::Document.generate(file_path) do |pdf|
        pdf.text '40-10007 Overflow Data', align: :center, size: 15
        pdf.move_down 10
        pdf.text 'The following pages contain data related to the application.', align: :center
        pdf.move_down 10

        if @data['version']
          pdf.text 'Question 7a Veteran/Servicemember Sex'
          pdf.text "Veteran/Servicemember Sex: #{veteran_sex}", size: 8
          pdf.move_down 10

          pdf.text 'Question 8 Ethnicity'
          pdf.text "Ethnicity: #{ethnicity}", size: 8
          pdf.move_down 10

          pdf.text 'Question 8 Race'
          pdf.text "Race: #{race}", size: 8
          pdf.move_down 10

          pdf.text 'Question 8 Race Comment'
          pdf.text "Comment: #{race_comment}", size: 8
          pdf.move_down 10

          pdf.text 'Question 10 Veteran/Servicemember Place of Birth (City)'
          pdf.text "Place of Birth (City): #{city_of_birth}", size: 8
          pdf.move_down 10

          pdf.text 'Question 10 Veteran/Servicemember Place of Birth (State)'
          pdf.text "Place of Birth (State): #{state_of_birth}", size: 8
          pdf.move_down 10

          pdf.text 'Question 14 Military Status Used to Apply for Eligibility'
          pdf.text "Military Status: #{military_status_label}", size: 8
        else
          pdf.text 'Question 10 Place of Birth'
          pdf.text "Place of Birth: #{place_of_birth}", size: 8
        end

        pdf.move_down 10

        if @data['version']
          %w[a b c].each do |letter|
            pdf.text "Question 15 Branch of Service #{letter.upcase}"
            pdf.text "Branch of Service: #{binding.local_variable_get("service_branch_value_#{letter}")}", size: 8
            pdf.move_down 10

            pdf.text "Question 18 Discharge - Character of Service #{letter.upcase}"
            pdf.text "Discharge Type: #{binding.local_variable_get("discharge_type_#{letter}")}", size: 8
            pdf.move_down 10

            pdf.text "Question 19 Highest Rank Attained #{letter.upcase}"
            pdf.text "Highest Rank: #{binding.local_variable_get("highest_rank_int_#{letter}")}", size: 8
            pdf.move_down 10
          end
        else
          %w[a b c].each_with_index do |letter, i|
            pdf.text "Question 15 Branch of Service Line #{i + 1}"
            pdf.text "Branch of Service: #{binding.local_variable_get("service_branch_value_#{letter}")}", size: 8
            pdf.move_down 10

            pdf.text "Question 18 Discharge - Character of Service Line #{i + 1}"
            pdf.text "Character of Service: #{binding.local_variable_get("discharge_type_#{letter}")}", size: 8
            pdf.move_down 10

            pdf.text "Question 19 Highest Rank Attained Line #{i + 1}"
            pdf.text "Highest Rank: #{binding.local_variable_get("highest_rank_#{letter}")}", size: 8
            pdf.move_down 10
          end
        end

        if @data['version']
          pdf.text 'Question 24 Claimant Relationship to Servicemember or Veteran'
          pdf.text "Claimant Relationship: #{relationship_to_veteran}", size: 8
          pdf.move_down 10

          pdf.text 'Sponsor Veteran/Servicemember Contact Details Email Address'
          pdf.text "Email Address: #{sponsor_veteran_email}", size: 8
          pdf.move_down 10

          pdf.text 'Sponsor Veteran/Servicemember Contact Details Phone Number'
          pdf.text "Phone Number: #{sponsor_veteran_phone}", size: 8
          pdf.move_down 10

          pdf.text 'Sponsor Veteran/Servicemember Maiden Name'
          pdf.text "Maiden Name: #{sponsor_veteran_maiden}", size: 8
          pdf.move_down 10
        end
      end
    end

    def handle_attachments(file_path)
      attachments = get_attachments

      merged_pdf = HexaPDF::Document.open(file_path)
      attachment_page_path = 'attachment_page.pdf'
      create_attachment_page(attachment_page_path)
      attachment_pdf = HexaPDF::Document.open(attachment_page_path)
      attachment_pdf.pages.each do |page|
        merged_pdf.pages << merged_pdf.import(page)
      end

      if attachments.count.positive?
        attachments.each do |attachment|
          attachment_pdf = HexaPDF::Document.open(attachment)
          attachment_pdf.pages.each do |page|
            merged_pdf.pages << merged_pdf.import(page)
          end
        rescue => e
          Rails.logger.error(
            'Simple forms api - failed to load attachment for 40-10007',
            { message: e.message, attachment: attachment.inspect }
          )
          raise
        end
      end

      merged_pdf.write(file_path, optimize: true)
      FileUtils.rm_f(attachment_page_path)
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    def track_user_identity(confirmation_number)
      identity = get_relationship_to_vet(@data.dig('application', 'claimant', 'relationship_to_vet'))
      StatsD.increment("#{STATS_KEY}.#{identity}")
      Rails.logger.info('Simple forms api - 40-10007 submission user identity', identity:, confirmation_number:)
    end

    def submission_date_stamps(_timestamp)
      []
    end

    def desired_stamps
      []
    end

    private

    def veteran_ssn_and_file_number
      [
        @data.dig('applicant', 'veteran', 'ssn')&.[](0..2),
        @data.dig('applicant', 'veteran', 'ssn')&.[](3..4),
        @data.dig('applicant', 'veteran', 'ssn')&.[](5..8),
        @data.dig('applicant', 'claimant', 'ssn')&.[](0..2),
        @data.dig('applicant', 'claimant', 'ssn')&.[](3..4),
        @data.dig('applicant', 'claimant', 'ssn')&.[](5..8),
        @data.dig('veteran_id', 'military_service_number')&.[](0..2),
        @data.dig('veteran_id', 'military_service_number')&.[](3..4),
        @data.dig('veteran_id', 'military_service_number')&.[](5..8),
        @data.dig('veteran_id', 'va_claim_number')&.[](0..2),
        @data.dig('veteran_id', 'va_claim_number')&.[](3..4),
        @data.dig('veteran_id', 'va_claim_number')&.[](5..8)
      ]
    end

    def veteran_dates_of_birth_and_death
      [
        data.dig('veteran', 'date_of_birth')&.[](0..3),
        data.dig('veteran', 'date_of_birth')&.[](5..6),
        data.dig('veteran', 'date_of_birth')&.[](8..9),
        data.dig('veteran', 'date_of_death')&.[](0..3),
        data.dig('veteran', 'date_of_death')&.[](5..6),
        data.dig('veteran', 'date_of_death')&.[](8..9),
        data.dig('claimant', 'date_of_birth')&.[](0..3),
        data.dig('claimant', 'date_of_birth')&.[](5..6),
        data.dig('claimant', 'date_of_birth')&.[](8..9)
      ]
    end

    def postal_code
      [
        data.dig('application', 'veteran', 'address', 'postal_code')&.[](0..4),
        data.dig('application', 'veteran', 'address', 'postal_code')&.[](5..8),
        data.dig('application', 'claimant', 'address', 'postal_code')&.[](0..4),
        data.dig('application', 'claimant', 'address', 'postal_code')&.[](5..8),
        data.dig('application', 'applicant', 'mailing_address', 'postal_code')&.[](0..4),
        data.dig('application', 'applicant', 'mailing_address', 'postal_code')&.[](5..8)
      ]
    end

    def phone_number
      [
        data.dig('application', 'claimant', 'phone_number')&.gsub('-', '')&.[](0..2),
        data.dig('application', 'claimant', 'phone_number')&.gsub('-', '')&.[](3..5),
        data.dig('application', 'claimant', 'phone_number')&.gsub('-', '')&.[](6..9),
        data.dig('application', 'applicant', 'applicant_phone_number')&.gsub('-', '')&.[](0..2),
        data.dig('application', 'applicant', 'applicant_phone_number')&.gsub('-', '')&.[](3..5),
        data.dig('application', 'applicant', 'applicant_phone_number')&.gsub('-', '')&.[](6..9)
      ]
    end

    def email
      [
        data.dig('application', 'claimant', 'email')&.[](0..14),
        data.dig('application', 'claimant', 'email')&.[](15..)
      ]
    end

    def get_attachments
      attachments = []

      supporting_documents = @data['application']['preneed_attachments']
      if supporting_documents
        confirmation_codes = []
        supporting_documents&.map { |doc| confirmation_codes << doc['confirmation_code'] }

        PersistentAttachment.where(guid: confirmation_codes).map { |attachment| attachments << attachment.to_pdf }
      end
      attachments
    end
  end
end
