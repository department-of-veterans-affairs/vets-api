# frozen_string_literal: true

require_relative '../section'

module Pensions
  module PdfFill
    # Section VII: Prior Marital History
    class Section7 < Section
      # Section configuration hash
      KEY = {
        # 7a-j Veteran's prior marriages
        'marriages' => {
          limit: 2,
          first_key: 'otherExplanation',
          item_label: 'Veteran\'s prior marriage',
          question_num: 7,
          'spouseFullName' => {
            'first' => {
              limit: 12,
              question_num: 7,
              question_suffix: 'A',
              question_label: 'Who Were You Married To? (First Name)',
              question_text: 'WHO WERE YOU MARRIED TO? (FIRST NAME)',
              key: "Marriages.Veterans_Prior_Spouse_FirstName[#{ITERATOR}]"
            },
            'middle' => {
              question_num: 7,
              question_suffix: 'A',
              question_label: 'Who Were You Married To? (Middle Name)',
              question_text: 'WHO WERE YOU MARRIED TO? (MIDDLE NAME)',
              key: "Marriages.Veterans_Prior_Spouse_MiddleInitial1[#{ITERATOR}]"
            },
            'last' => {
              limit: 18,
              question_num: 7,
              question_suffix: 'A',
              question_label: 'Who Were You Married To? (Last Name)',
              question_text: 'WHO WERE YOU MARRIED TO? (LAST NAME)',
              key: "Marriages.Veterans_Prior_Spouse_LastName[#{ITERATOR}]"
            }
          },
          'spouseFullNameOverflow' => {
            question_num: 7,
            question_suffix: 'A',
            question_label: 'Who Were You Married To?',
            question_text: '(1) WHO WERE YOU MARRIED TO?'
          },
          'reasonForSeparation' => {
            key: "Marriages.Previous_Marriage_End_Reason[#{ITERATOR}]"
          },
          'reasonForSeparationOverflow' => {
            question_num: 7,
            question_suffix: 'A',
            question_label: 'How Did Your Previous Marriage End?',
            question_text: '(2) HOW DID YOUR PREVIOUS MARRIAGE END?'
          },
          'otherExplanation' => {
            limit: 43,
            question_num: 7,
            question_suffix: 'A',
            question_label: 'How Did Your Previous Marriage End (Other Reason)?',
            question_text: '(2) HOW DID YOUR PREVIOUS MARRIAGE END (OTHER REASON)?',
            key: "Marriages.Other_Specify[#{ITERATOR}]"
          },
          'dateOfMarriage' => {
            'month' => {
              key: "Marriages.Date_Of_Prior_Marriage_Start_Month[#{ITERATOR}]"
            },
            'day' => {
              key: "Marriages.Date_Of_Prior_Marriage_Start_Day[#{ITERATOR}]"
            },
            'year' => {
              key: "Marriages.Date_Of_Prior_Marriage_Start_Year[#{ITERATOR}]"
            }
          },
          'dateOfSeparation' => {
            'month' => {
              key: "Marriages.Date_Of_Prior_Marriage_End_Month[#{ITERATOR}]"
            },
            'day' => {
              key: "Marriages.Date_Of_Prior_Marriage_End_Day[#{ITERATOR}]"
            },
            'year' => {
              key: "Marriages.Date_Of_Prior_Marriage_End_Year[#{ITERATOR}]"
            }
          },
          'dateRangeOfMarriageOverflow' => {
            question_num: 7,
            question_suffix: 'A',
            question_label: 'What Are The Dates Of The Previous Marriage?',
            question_text: '(3) WHAT ARE THE DATES OF THE PREVIOUS MARRIAGE?'
          },
          'locationOfMarriage' => {
            limit: 63,
            question_num: 7,
            question_suffix: 'A',
            question_label: 'Place Of Marriage',
            question_text: '(4) PLACE OF MARRIAGE',
            key: "Marriages.Place_Of_Marriage_City_And_State_Or_Country[#{ITERATOR}]"
          },
          'locationOfSeparation' => {
            limit: 54,
            question_num: 7,
            question_suffix: 'A',
            question_label: 'Place Marriage Ended',
            question_text: '(5) PLACE MARRIAGE ENDED',
            key: "Marriages.Place_Of_Marriage_Termination_City_And_State_Or_Country[#{ITERATOR}]"
          }
        },
        # 7l-u Spouse's prior marriages
        'spouseMarriages' => {
          limit: 2,
          item_label: 'Veteran\'s spouse prior marriage',
          first_key: 'otherExplanation',
          'spouseFullName' => {
            'first' => {
              limit: 12,
              question_num: 7,
              question_suffix: 'B',
              question_label: 'Who Was Your Spouse Married To? (First Name)',
              question_text: 'WHO WAS YOUR SPOUSE MARRIED TO? (FIRST NAME)',
              key: "Spouse_Marriages.Spouses_Prior_Spouse_FirstName[#{ITERATOR}]"
            },
            'middle' => {
              question_num: 7,
              question_suffix: 'B',
              question_label: 'Who Was Your Spouse Married To? (Middle Name)',
              question_text: 'WHO WAS YOUR SPOUSE MARRIED TO? (MIDDLE NAME)',
              key: "Spouse_Marriages.Spouses_Prior_Spouse_MiddleInitial1[#{ITERATOR}]"
            },
            'last' => {
              limit: 18,
              question_num: 7,
              question_suffix: 'B',
              question_label: 'Who Was Your Spouse Married To? (Last Name)',
              question_text: 'WHO WAS YOUR SPOUSE MARRIED TO? (LAST NAME)',
              key: "Spouse_Marriages.Spouses_Prior_Spouse_LastName[#{ITERATOR}]"
            }
          },
          'spouseFullNameOverflow' => {
            question_num: 7,
            question_suffix: 'B',
            question_label: 'Who Was Your Spouse Married To?',
            question_text: '(1) WHO WAS YOUR SPOUSE MARRIED TO?'
          },
          'reasonForSeparation' => {
            key: "Spouse_Marriages.Previous_Marriage_End_Reason[#{ITERATOR}]"
          },
          'reasonForSeparationOverflow' => {
            question_num: 7,
            question_suffix: 'B',
            question_label: 'How Did The Previous Marriage End?',
            question_text: '(2) HOW DID THE PREVIOUS MARRIAGE END?'
          },
          'otherExplanation' => {
            limit: 43,
            question_num: 7,
            question_suffix: 'B',
            question_label: 'How Did The Previous Marriage End (Other Reason)?',
            question_text: '(2) HOW DID THE PREVIOUS MARRIAGE END (OTHER REASON)?',
            key: "Spouse_Marriages.Other_Specify[#{ITERATOR}]"
          },
          'dateOfMarriage' => {
            'month' => {
              key: "Spouse_Marriages.Date_Of_Prior_Marriage_Start_Month[#{ITERATOR}]"
            },
            'day' => {
              key: "Spouse_Marriages.Date_Of_Prior_Marriage_Start_Day[#{ITERATOR}]"
            },
            'year' => {
              key: "Spouse_Marriages.Date_Of_Prior_Marriage_Start_Year[#{ITERATOR}]"
            }
          },
          'dateOfSeparation' => {
            'month' => {
              key: "Spouse_Marriages.Date_Of_Prior_Marriage_End_Month[#{ITERATOR}]"
            },
            'day' => {
              key: "Spouse_Marriages.Date_Of_Prior_Marriage_End_Day[#{ITERATOR}]"
            },
            'year' => {
              key: "Spouse_Marriages.Date_Of_Prior_Marriage_End_Year[#{ITERATOR}]"
            }
          },
          'dateRangeOfMarriageOverflow' => {
            question_num: 7,
            question_suffix: 'B',
            question_label: 'What Are The Dates Of The Previous Marriage?',
            question_text: '(3) WHAT ARE THE DATES OF THE PREVIOUS MARRIAGE?'
          },
          'locationOfMarriage' => {
            limit: 63,
            question_num: 7,
            question_suffix: 'B',
            question_label: 'Place Of Marriage',
            question_text: '(4) PLACE OF MARRIAGE',
            key: "Spouse_Marriages.Place_Of_Marriage_City_And_State_Or_Country[#{ITERATOR}]"
          },
          'locationOfSeparation' => {
            limit: 54,
            question_num: 7,
            question_suffix: 'B',
            question_label: 'Place Marriage Ended',
            question_text: '(5) PLACE MARRIAGE ENDED',
            key: "Spouse_Marriages.Place_Of_Marriage_Termination_City_And_State_Or_Country[#{ITERATOR}]"
          }
        },
        # 7k
        'additionalMarriages' => {
          key: 'form1[0].#subform[50].RadioButtonList[15]'
        },
        # 7v
        'additionalSpouseMarriages' => {
          key: 'form1[0].#subform[50].RadioButtonList[17]'
        }
      }.freeze

      ##
      # Expand the form data for prior marital history.
      #
      # @param form_data [Hash] The form data hash.
      #
      # @return [void]
      #
      # Note: This method modifies `form_data`
      #
      def expand(form_data)
        expand_prior_marital_history(form_data)
      end

      ##
      # Expand prior marital history data.
      #
      # @param form_data [Hash] The form data hash.
      #
      # @return [void]
      #
      #  Note: This method modifies `form_data`
      #
      def expand_prior_marital_history(form_data)
        form_data['marriages'] = build_marital_history(form_data['marriages'], 'VETERAN')
        form_data['spouseMarriages'] = build_marital_history(form_data['spouseMarriages'], 'SPOUSE')
        if form_data['marriages']&.any?
          form_data['additionalMarriages'] = to_radio_yes_no(form_data['marriages'].length.to_i > 3)
        end
        if form_data['spouseMarriages']&.any?
          form_data['additionalSpouseMarriages'] = to_radio_yes_no(form_data['spouseMarriages'].length.to_i > 2)
        end
      end

      ##
      # Build marital history entries.
      #
      # @param marriages [Array<Hash>] The array of marriage entries.
      # @param marriage_for [String] Indicates whether the marriages are for 'VETERAN' or 'SPOUSE'.
      #
      # @return [Array<Hash>] The processed array of marriage entries.
      #
      def build_marital_history(marriages, marriage_for = 'VETERAN')
        return [] unless marriages.present? && %w[VETERAN SPOUSE].include?(marriage_for)

        marriages.map do |marriage|
          reason_for_separation = marriage['reasonForSeparation'].to_s
          marriage_date_range = {
            'from' => marriage['dateOfMarriage'],
            'to' => marriage['dateOfSeparation']
          }
          marriage.merge!({ 'spouseFullNameOverflow' => marriage['spouseFullName']&.values&.join(' '),
                            'dateOfMarriage' => split_date(marriage['dateOfMarriage']),
                            'dateOfSeparation' => split_date(marriage['dateOfSeparation']),
                            'dateRangeOfMarriageOverflow' => build_date_range_string(marriage_date_range),
                            'reasonForSeparation' => Constants::REASONS_FOR_SEPARATION[reason_for_separation],
                            'reasonForSeparationOverflow' => reason_for_separation.humanize })
          marriage['spouseFullName']['middle'] = marriage['spouseFullName']['middle']&.first
          marriage
        end
      end
    end
  end
end
