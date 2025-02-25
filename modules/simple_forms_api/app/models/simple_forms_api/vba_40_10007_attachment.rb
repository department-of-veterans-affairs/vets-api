# frozen_string_literal: true

module SimpleFormsApi
  class VBA4010007Attachment
    attr_reader :file_path, :data

    GENDER = {
      'Male' => 'Male',
      'Female' => 'Female',
      'na' => 'Prefer not to answer'
    }.freeze

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
      'XG' => 'Coast Guard Reserve',
      'AD' => 'U.S. Army Signal Corps Aero Div',
      'AS' => 'U.S. Army Air Service',
      'AV' => 'U.S. Army Signal Corps Avn Sec',
      'CW' => 'U.S. Civ of Afs WWI',
      'DT' => 'Dietitian World War I',
      'FC' => 'Engineer Field Clerk WWI',
      'IR' => 'Irregular Forces Laos',
      'NC' => 'Army Nurse Corps',
      'O1' => 'Confederate States Army',
      'O2' => 'Prov Army Confederate States',
      'O3' => 'Confederate States Navy',
      'O4' => 'Prov Navy Confederate States',
      'O5' => 'Confederate States Mar Corps',
      'O6' => 'Prov Mar Corps Confederate St',
      'OA' => 'Army Corps',
      'OB' => 'Artillery',
      'OC' => 'Battalion',
      'OD' => 'Battery',
      'OE' => 'Cavalry',
      'OF' => 'Commissary of Substance',
      'OH' => 'Division Hospital',
      'OI' => 'General Hospital',
      'OJ' => 'Infantry',
      'OK' => 'Regiment',
      'OL' => 'Regimental Hospital',
      'ON' => 'Veteran Reserve Corps',
      'OP' => 'Volunteers',
      'OR' => 'U.S. Revenue Cutter Service',
      'OT' => 'U.S. Cld Troops',
      'OU' => 'Continental Line',
      'OV' => 'Continental Navy',
      'OW' => 'Continental Marine',
      'OX' => 'Provisional Army',
      'OY' => 'Provisional Navy',
      'OZ' => 'Provisional Marine Regt',
      'QC' => 'Quartermstr Corp Female Clerk',
      'RA' => 'Reconstruction Aide',
      'RR' => 'Russian Railway Service',
      'SA' => 'U.S. Space Force',
      'SF' => 'Signal Corps Tel Oper',
      'SP' => 'Special Guerilla Unit Laos',
      'UT' => 'Utah Territorial Militia'
    }.freeze

    DISCHARGE_TYPE = {
      '1' => 'Honorable',
      '2' => 'General',
      '3' => 'Entry Level Separation/Uncharacterized',
      '4' => 'Other Than Honorable',
      '5' => 'Bad Conduct',
      '6' => 'Dishonorable',
      '7' => 'Other'
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

    def initialize(file_path:, data:)
      @file_path = file_path
      @data = data
    end

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def create
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
      highest_rank_a = @data.dig('application', 'veteran', 'service_records', 0, 'highest_rank') || ''
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

      if @data['version']
        race_data = @data.dig('application', 'veteran', 'race')
        race = ''.dup
        race += 'American Indian or Alaskan Native, ' if race_data['is_american_indian_or_alaskan_native']
        race += 'Asian, ' if race_data['is_asian']
        race += 'Black or African American, ' if race_data['is_black_or_african_american']
        if race_data['is_native_hawaiian_or_other_pacific_islander']
          race += 'Native Hawaiian or other Pacific Islander, '
        end
        race += 'White, ' if race_data['is_white']
        race += 'Prefer not to answer, ' if race_data['na']
        race += 'Other, ' if race_data['is_other']
        race.chomp!(', ')
      end

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
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    private

    def get_gender(key)
      GENDER[key]
    end

    def get_service_label(key)
      SERVICE_LABELS[key]
    end

    def get_discharge_label(key)
      DISCHARGE_TYPE[key]
    end

    def get_ethnicity_labels(key)
      ETHNICITY_VALUES[key]
    end

    def get_military_status(key)
      MILITARY_STATUS[key]
    end
  end
end
