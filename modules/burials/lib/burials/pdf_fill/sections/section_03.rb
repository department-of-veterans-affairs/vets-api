# frozen_string_literal: true

require_relative '../section'

module Burials
  module PdfFill
    # Section III: Veteran Service Information
    class Section3 < Section
      # rubocop:disable Layout/LineLength
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
          question_label: 'If Veteran Served Under Name Other Than That Shown In Item 1, Give Full Name And Service Rendered Under That Name',
          question_text: 'IF VETERAN SERVED UNDER NAME OTHER THAN THAT SHOWN IN ITEM 1, GIVE FULL NAME AND SERVICE RENDERED UNDER THAT NAME',
          limit: 180
        }
      }.freeze
      # rubocop:enable Layout/LineLength

      ##
      # Expands the form data for Section 3.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        # Add expansion logic here
      end
    end
  end
end
