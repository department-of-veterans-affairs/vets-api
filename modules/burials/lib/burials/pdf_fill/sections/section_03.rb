# frozen_string_literal: true

require_relative '../section'

module Burials
  module PdfFill
    # Section III: Veteran Service Information
    class Section3 < Section
      # Section configuration hash
      KEY = {
        'toursOfDuty' => {
          limit: 3,
          first_key: 'rank',
          item_label: 'Service period',
          'dateRangeStart' => {
            key: "form1[0].#subform[82].DATE_ENTERED_SERVICE[#{ITERATOR}]",
            question_num: 14,
            question_suffix: 'A(1)',
            question_label: 'Entered Service (Date)',
            question_text: 'ENTERED SERVICE (date)',
            format: 'date'
          },
          'placeOfEntry' => {
            key: "form1[0].#subform[82].PLACE[#{ITERATOR}]",
            limit: 25,
            question_num: 14,
            question_suffix: 'A(2)',
            question_label: 'Entered Service (Place)',
            question_text: 'ENTERED SERVICE (place)'
          },
          'militaryServiceNumber' => {
            key: "form1[0].#subform[82].SERVICE_NUMBER[#{ITERATOR}]",
            limit: 12,
            question_num: 14,
            question_suffix: 'B',
            question_label: 'Service Number',
            question_text: 'SERVICE NUMBER'
          },
          'dateRangeEnd' => {
            key: "form1[0].#subform[82].DATE_SEPARATED_SERVICE[#{ITERATOR}]",
            question_num: 14,
            question_suffix: 'C(1)',
            question_label: 'Separated From Service (Date)',
            question_text: 'SEPARATED FROM SERVICE (date)',
            format: 'date'
          },
          'placeOfSeparation' => {
            key: "form1[0].#subform[82].PLACE_SEPARATED[#{ITERATOR}]",
            question_num: 14,
            question_suffix: 'C(2)',
            question_label: 'Separated From Service (Place)',
            question_text: 'SEPARATED FROM SERVICE (place)',
            limit: 25
          },
          'rank' => {
            key: "form1[0].#subform[82].GRADE_RANK_OR_RATING[#{ITERATOR}]",
            question_num: 14,
            question_suffix: 'D(1)',
            question_label: 'Grade, Rank Or Rating, Organization And Branch Of Service',
            question_text: 'GRADE, RANK OR RATING, ORGANIZATION AND BRANCH OF SERVICE',
            limit: 31
          }
        },
        'previousNames' => {
          key: 'form1[0].#subform[82].OTHER_NAME_VETERAN_SERVED_UNDER[0]',
          question_num: 15,
          question_label: 'Other Names Veteran Served Under',
          question_text: 'OTHER NAMES VETERAN SERVED UNDER',
          limit: 120
        }
      }.freeze
      ##
      # Expands the form data for Section 3.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        form_data['previousNames'] = expand_previous_names_and_service(form_data['previousNames'])
        tours_of_duty = form_data['toursOfDuty']
        return if tours_of_duty.blank?

        tours_of_duty.each do |tour_of_duty|
          expand_date_range(tour_of_duty, 'dateRange')
          tour_of_duty['rank'] = combine_hash(tour_of_duty, %w[serviceBranch rank unit], ', ')
          tour_of_duty['militaryServiceNumber'] = form_data['militaryServiceNumber']
        end
      end

      ##
      # Combines the previous names and their corresponding service branches into a formatted string
      #
      # @param previous_names [Array<Hash>]
      #
      # @return [String, nil]
      def expand_previous_names_and_service(previous_names)
        return if previous_names.blank?

        formatted_names = previous_names.map do |previous_name|
          service_info = previous_name['serviceBranch'].present? ? "(#{previous_name['serviceBranch']})" : ''
          "#{combine_full_name(previous_name)} #{service_info}"
        end

        # Join with semicolons for length check
        semicolon_joined = formatted_names.join('; ')

        # Check against the character limit defined in KEY configuration
        character_limit = KEY['previousNames'][:limit]

        # If the semicolon-joined string exceeds the limit, use newlines for overflow format
        if semicolon_joined.length > character_limit
          formatted_names.join("\n")
        else
          semicolon_joined
        end
      end
    end
  end
end
