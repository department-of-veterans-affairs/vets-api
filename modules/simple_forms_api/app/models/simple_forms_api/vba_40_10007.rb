# frozen_string_literal: true

require 'json'

module SimpleFormsApi
  class VBA4010007
    include Virtus.model(nullify_blank: true)
    STATS_KEY = 'api.simple_forms_api.40_10007'

    attribute :data

    def initialize(data)
      @data = data
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('application', 'claimant', 'name', 'first'),
        'veteranLastName' => @data.dig('application', 'claimant', 'name', 'last'),
        'fileNumber' => @data.dig('application', 'claimant', 'ssn')&.gsub('-', ''),
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
      '1' => 'Applicant is service memebr or veteran',
      '2' => 'Spouse or surviving spouse',
      '3' => 'Unmarried adult child',
      '4' => 'other'
    }.freeze

    def get_relationship_to_vet(key)
      RELATIONSHIP_TO_VETS[key]
    end

    # rubocop:disable Metrics/MethodLength
    def create_attachment_page(file_path)
      place_of_birth = @data.dig('application', 'veteran', 'place_of_birth')
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
      highest_rank_a = @data.dig('application', 'veteran', 'service_records', 0, 'highest_rank') || ''
      highest_rank_b = @data.dig('application', 'veteran', 'service_records', 1, 'highest_rank') || ''
      highest_rank_c = @data.dig('application', 'veteran', 'service_records', 2, 'highest_rank') || ''

      Prawn::Document.generate(file_path) do |pdf|
        pdf.text '40-10007 Overflow Data', align: :center, size: 20
        pdf.move_down 20
        pdf.text 'The following pages contain data related to the application.', align: :center
        pdf.move_down 20
        pdf.text 'Question 10 Place of Birth'
        pdf.text "Place of Birth: #{place_of_birth}", size: 10
        pdf.move_down 10
        pdf.text 'Question 15 Branch of Service Line 1'
        pdf.text "Branch of Service: #{service_branch_value_a}", size: 10
        pdf.move_down 10
        pdf.text 'Question 18 Discharge - Character of Service Line 1'
        pdf.text "Character of Service: #{discharge_type_a}", size: 10
        pdf.move_down 10
        pdf.text 'Question 19 Highest Rank Attained Line 1'
        pdf.text "Highest Rank Attained: #{highest_rank_a}", size: 10
        pdf.move_down 10
        pdf.text 'Question 15 Branch of Service Line 2'
        pdf.text "Branch of Service: #{service_branch_value_b}", size: 10
        pdf.move_down 10
        pdf.text 'Question 18 Discharge - Character of Service Line 2'
        pdf.text "Character of Service: #{discharge_type_b}", size: 10
        pdf.move_down 10
        pdf.text 'Question 19 Highest Rank Attained Line 2'
        pdf.text "Highest Rank Attained: #{highest_rank_b}", size: 10
        pdf.move_down 10
        pdf.text 'Question 15 Branch of Service Line 3'
        pdf.text "Branch of Service: #{service_branch_value_c}", size: 10
        pdf.move_down 10
        pdf.text 'Question 18 Discharge - Character of Service Line 3'
        pdf.text "Character of Service: #{discharge_type_c}", size: 10
        pdf.move_down 10
        pdf.text 'Question 19 Highest Rank Attained Line 3'
        pdf.text "Highest Rank Attained: #{highest_rank_c}", size: 10
      end
    end

    # rubocop:enable Metrics/MethodLength
    def handle_attachments(file_path)
      attachments = get_attachments
      combined_pdf = CombinePDF.new
      combined_pdf << CombinePDF.load(file_path)

      attachment_page_path = 'attachment_page.pdf'
      create_attachment_page(attachment_page_path)
      combined_pdf << CombinePDF.load(attachment_page_path)

      attachments.each do |attachment|
        combined_pdf << CombinePDF.load(attachment)
      end

      combined_pdf.save file_path

      FileUtils.rm_f(attachment_page_path)
    end

    def track_user_identity(confirmation_number)
      identity = @data.dig('application', 'claimant', 'relationship_to_vet')
      StatsD.increment("#{STATS_KEY}.#{get_relationship_to_vet(identity)}")
      Rails.logger.info('Simple forms api - 40-10007 submission user identity', identity:, confirmation_number:)
    end

    def submission_date_stamps
      []
    end

    private

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
