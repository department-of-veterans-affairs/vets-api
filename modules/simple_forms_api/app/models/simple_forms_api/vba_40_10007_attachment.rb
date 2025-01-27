# frozen_string_literal: true

module SimpleFormsApi
  class VBA4010007Attachment
    attr_reader :file_path, :data

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
  end
end
