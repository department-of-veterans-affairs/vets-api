# frozen_string_literal: true

require_relative '../section'

module Pensions
  module PdfFill
    # Section VI: Marital Status
    class Section6 < Section
      # Section configuration hash
      KEY = {
        # 6a
        'maritalStatus' => {
          key: 'form1[0].#subform[49].RadioButtonList[10]'
        },
        'currentMarriage' => {
          # 6b
          'spouseFullName' => {
            'first' => {
              limit: 12,
              question_num: 6,
              question_suffix: 'B',
              question_label: "Spouse's Current First Name",
              question_text: 'SPOUSE\'S CURRENT FIRST NAME',
              key: 'form1[0].#subform[49].Spouses_Current_Legal_Name_First_Name[0]'
            },
            'middle' => {
              key: 'form1[0].#subform[49].Spouses_Middle_Initial1[0]'
            },
            'last' => {
              limit: 18,
              question_num: 6,
              question_suffix: 'B',
              question_label: "Spouse's Current Last Name",
              question_text: 'SPOUSE\'S CURRENT LAST NAME',
              key: 'form1[0].#subform[49].Spouses_Last_Name[0]'
            }
          },
          # 6c
          'spouseDateOfBirth' => {
            'month' => {
              key: 'form1[0].#subform[49].DOB_Month[0]'
            },
            'day' => {
              key: 'form1[0].#subform[49].DOB_Day[0]'
            },
            'year' => {
              key: 'form1[0].#subform[49].DOB_Year[0]'
            }
          },
          # 6d
          'spouseSocialSecurityNumber' => {
            'first' => {
              key: 'form1[0].#subform[49].Spouses_SocialSecurityNumber_FirstThreeNumbers[0]'
            },
            'second' => {
              key: 'form1[0].#subform[49].Spouses_SocialSecurityNumber_SecondTwoNumbers[0]'
            },
            'third' => {
              key: 'form1[0].#subform[49].Spouses_SocialSecurityNumber_LastFourNumbers[0]'
            }
          },
          # 6e
          'dateOfMarriage' => {
            'month' => {
              key: 'form1[0].#subform[49].Date_Of_Marriage_Month[0]'
            },
            'day' => {
              key: 'form1[0].#subform[49].Date_Of_Marriage_Day[0]'
            },
            'year' => {
              key: 'form1[0].#subform[49].Date_Of_Marriage_Year[0]'
            }
          },
          'locationOfMarriage' => {
            limit: 22,
            question_num: 6,
            question_suffix: 'E',
            question_label: 'Place Of Marriage City And State Or Country',
            question_text: 'PLACE OF MARRIAGE CITY AND STATE OR COUNTRY',
            key: 'form1[0].#subform[49].Place_Of_Marriage_City_And_State_Or_Country[0]'
          },
          # 6f
          'marriageType' => {
            key: 'form1[0].#subform[49].RadioButtonList[11]'
          },
          'otherExplanation' => {
            limit: 22,
            question_num: 6,
            question_suffix: 'F',
            question_label: 'Specify Type Of Marriage',
            question_text: 'SPECIFY TYPE OF MARRIAGE',
            key: 'form1[0].#subform[49].Other_Specify[0]'
          }
        },
        # 6g
        'spouseIsVeteran' => {
          key: 'form1[0].#subform[49].RadioButtonList[12]'
        },
        # 6h
        'spouseVaFileNumber' => {
          key: 'form1[0].#subform[49].Spouses_VAFileNumber_If_Any[0]'
        },
        # 6i
        'reasonForCurrentSeparation' => {
          key: 'form1[0].#subform[49].RadioButtonList[13]'
        },
        'otherExplanation' => {
          limit: 39,
          question_num: 6,
          question_suffix: 'I',
          question_text: '',
          key: 'form1[0].#subform[49].Other_Specify[1]'
        },
        # 6j
        'spouseAddress' => {
          'street' => {
            limit: 30,
            question_num: 6,
            question_suffix: 'J',
            question_label: 'Spouse Mailing Address Street',
            question_text: 'SPOUSE MAILING ADDRESS STREET',
            key: 'form1[0].#subform[49].Number_And_Street[0]'
          },
          'street2' => {
            limit: 5,
            question_num: 6,
            question_suffix: 'J',
            question_label: 'Spouse Mailing Address Apt Number',
            question_text: 'SPOUSE MAILING ADDRESS APT NUMBER',
            key: 'form1[0].#subform[49].Apt_Or_Unit_Number[1]'
          },
          'city' => {
            limit: 18,
            question_num: 6,
            question_suffix: 'J',
            question_label: 'Spouse Mailing Address City',
            question_text: 'SPOUSE MAILING ADDRESS CITY',
            key: 'form1[0].#subform[49].City[1]'
          },
          'state' => {
            key: 'form1[0].#subform[49].State_Or_Province[0]'
          },
          'country' => {
            key: 'form1[0].#subform[49].Country[1]'
          },
          'postalCode' => {
            'firstFive' => {
              key: 'form1[0].#subform[49].Zip_Postal_Code[2]'
            },
            'lastFour' => {
              key: 'form1[0].#subform[49].Zip_Postal_Code[3]'
            }
          }
        },
        # 6k
        'currentSpouseMonthlySupport' => {
          'part_two' => {
            key: 'form1[0].#subform[49].Monthly_Amount[0]'
          },
          'part_one' => {
            key: 'form1[0].#subform[49].Monthly_Amount[1]'
          },
          'part_cents' => {
            key: 'form1[0].#subform[49].Monthly_Amount[2]'
          }
        }
      }.freeze

      ##
      # Expand the form data for current marital status.
      #
      # @param form_data [Hash] The form data hash.
      #
      # @return [void]
      #
      # Note: This method modifies `form_data`
      #
      def expand(form_data)
        # Add expansion logic here
      end
    end
  end
end
