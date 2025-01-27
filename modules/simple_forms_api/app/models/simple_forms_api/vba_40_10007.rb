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

    def notification_first_name
      applicant_relationship = @data.dig('application', 'applicant', 'applicant_relationship_to_claimant')

      if applicant_relationship == 'Self'
        @data.dig('application', 'claimant', 'name', 'first')
      else
        @data.dig('application', 'applicant', 'name', 'first')
      end
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

    def create_attachment_page(file_path)
      SimpleFormsApi::VBA4010007Attachment.new(file_path:, data:).create
    end

    # rubocop:disable Metrics/MethodLength
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
    # rubocop:enable Metrics/MethodLength

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
