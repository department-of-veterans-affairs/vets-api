# frozen_string_literal: true

require 'survivors_benefits/pdf_fill/section'

require_relative '../../constants'

module SurvivorsBenefits
  module PdfFill
    # Section 6: Children of the Veteran Information
    class Section6 < Section
      ITERATOR = ::PdfFill::HashConverter::ITERATOR
      CHILD_ROW_INDEX = ->(iterator) { 2 - iterator }
      CHILD_SSN_INDEX = ->(iterator) { (iterator + 1) % 3 }
      CHILD_DOB_INDEX = ->(iterator) { 8 + ((iterator + 1) % 3) }

      KEY = {
        'p13HeaderVeteranSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[210].VeteransSocialSecurityNumber_FirstThreeNumbers[3]'
          },
          'second' => {
            key: 'form1[0].#subform[210].VeteransSocialSecurityNumber_SecondTwoNumbers[3]'
          },
          'third' => {
            key: 'form1[0].#subform[210].VeteransSocialSecurityNumber_LastFourNumbers[3]'
          }
        },
        'veteranChildrenCount' => {
          key: 'form1[0].#subform[210].Number_Of_Dependent_Children[0]'
        },
        'veteransChildren' => {
          limit: 3,
          first_key: 'childFullName',
          'childFullName' => {
            'first' => {
              limit: 12,
              question_num: 1,
              question_suffix: 'A',
              question_label: "Child's First Name",
              question_text: 'CHILD\'S FIRST NAME',
              iterator_offset: CHILD_ROW_INDEX,
              key: "form1[0].#subform[210].Childs_FirstName[#{ITERATOR}]"
            },
            'middle' => {
              limit: 1,
              question_num: 1,
              question_suffix: 'A',
              iterator_offset: CHILD_ROW_INDEX,
              key: "form1[0].#subform[210].Childs_MiddleInitial1[#{ITERATOR}]"
            },
            'last' => {
              limit: 18,
              question_num: 1,
              question_suffix: 'A',
              question_label: "Child's Last Name",
              question_text: 'CHILD\'S LAST NAME',
              iterator_offset: CHILD_ROW_INDEX,
              key: "form1[0].#subform[210].Childs_LastName[#{ITERATOR}]"
            }
          },
          'childDateOfBirth' => {
            'month' => {
              iterator_offset: CHILD_DOB_INDEX,
              key: "form1[0].#subform[210].Date_Month[#{ITERATOR}]"
            },
            'day' => {
              iterator_offset: CHILD_DOB_INDEX,
              key: "form1[0].#subform[210].Date_Day[#{ITERATOR}]"
            },
            'year' => {
              iterator_offset: CHILD_DOB_INDEX,
              key: "form1[0].#subform[210].Date_Year[#{ITERATOR}]"
            }
          },
          'childSocialSecurityNumber' => {
            'first' => {
              iterator_offset: CHILD_SSN_INDEX,
              key: "form1[0].#subform[210].Childs_SocialSecurityNumber_FirstThreeNumbers[#{ITERATOR}]"
            },
            'second' => {
              iterator_offset: CHILD_SSN_INDEX,
              key: "form1[0].#subform[210].Childs_SocialSecurityNumber_SecondTwoNumbers[#{ITERATOR}]"
            },
            'third' => {
              iterator_offset: CHILD_SSN_INDEX,
              key: "form1[0].#subform[210].Childs_SocialSecurityNumber_LastFourNumbers[#{ITERATOR}]"
            }
          },
          'childPlaceOfBirth' => {
            iterator_offset: CHILD_ROW_INDEX,
            key: "form1[0].#subform[210].Place_Of_Birth_City_State_Or_Country[#{ITERATOR}]"
          },
          'childStatusBiological' => {
            iterator_offset: CHILD_ROW_INDEX,
            key: "form1[0].#subform[210].JF06[#{ITERATOR}]"
          },
          'childStatusAdopted' => {
            iterator_offset: CHILD_ROW_INDEX,
            key: "form1[0].#subform[210].JF14[#{ITERATOR}]"
          },
          'childStatusStepchild' => {
            iterator_offset: CHILD_ROW_INDEX,
            key: "form1[0].#subform[210].JF08[#{ITERATOR}]"
          },
          'childStatusMinor' => {
            iterator_offset: CHILD_ROW_INDEX,
            key: "form1[0].#subform[210].JF12[#{ITERATOR}]"
          },
          'childStatusDisabled' => {
            iterator_offset: CHILD_ROW_INDEX,
            key: "form1[0].#subform[210].JF10[#{ITERATOR}]"
          },
          'childStatusMarried' => {
            iterator_offset: CHILD_ROW_INDEX,
            key: "form1[0].#subform[210].JF18[#{ITERATOR}]"
          },
          'childStatusSupported' => {
            iterator_offset: CHILD_ROW_INDEX,
            key: "form1[0].#subform[210].JF16[#{ITERATOR}]"
          },
          'childSupport' => {
            'thousands' => {
              iterator_offset: ->(iterator) { 3 - iterator },
              key_from_iterator: lambda { |iterator|
                case iterator
                when 0 then 'form1[0].#subform[210].Monthly_Amount_Contribution[1]'
                else "form1[0].#subform[210].Total_Annual_Earnings_Amount[#{ITERATOR}]"
                end
              }
            },
            'dollars' => {
              iterator_offset: ->(iterator) { 6 - (iterator * 3) },
              key_from_iterator: lambda { |iterator|
                case iterator
                when 0 then 'form1[0].#subform[210].Monthly_Amount_Contribution[0]'
                else "form1[0].#subform[210].Total_Annual_Earnings_Amount[#{ITERATOR}]"
                end
              }
            }
          }
        },
        'childrenLiveTogetherButNotWithSpouse' => {
          key: 'form1[0].#subform[210].RadioButtonList[23]'
        },
        'custodianFullName' => {
          'first' => {
            limit: 12,
            question_num: 1,
            question_suffix: 'A',
            question_label: 'Custodian\'s First Name',
            question_text: 'CUSTODIAN\'S FIRST NAME',
            key: 'form1[0].#subform[210].Custodians_FirstName[0]'
          },
          'middle' => {
            limit: 1,
            question_num: 1,
            question_suffix: 'A',
            key: 'form1[0].#subform[210].Custodians_MiddleInitial1[0]'
          },
          'last' => {
            limit: 18,
            question_num: 1,
            question_suffix: 'A',
            question_label: "Custodian's Last Name",
            question_text: 'CUSTODIAN\'S LAST NAME',
            key: 'form1[0].#subform[210].Custodians_LastName[0]'
          }
        },
        'custodianAddress' => {
          'street' => {
            limit: 30,
            question_num: 2,
            question_suffix: 'A',
            question_label: 'Mailing Address Number And Street',
            question_text: 'MAILING ADDRESS NUMBER AND STREET',
            key: 'form1[0].#subform[210].NumberStreet[2]'
          },
          'street2' => {
            limit: 5,
            question_num: 2,
            question_suffix: 'A',
            question_label: 'Mailing Address Apt/Unit',
            question_text: 'MAILING ADDRESS APT/UNIT',
            key: 'form1[0].#subform[210].Apt_Or_Unit_Number[1]'
          },
          'city' => {
            limit: 18,
            question_num: 2,
            question_suffix: 'A',
            question_label: 'Mailing Address City',
            question_text: 'MAILING ADDRESS CITY',
            key: 'form1[0].#subform[210].City[1]'
          },
          'state' => {
            key: 'form1[0].#subform[210].State_Province[1]'
          },
          'country' => {
            key: 'form1[0].#subform[210].Country[1]'
          },
          'postalCode' => {
            'firstFive' => {
              key: 'form1[0].#subform[210].Zip_Postal_Code[2]'
            },
            'lastFour' => {
              limit: 4,
              question_num: 2,
              question_suffix: 'A',
              question_label: 'Postal Code - Last Four',
              question_text: 'POSTAL CODE - LAST FOUR',
              key: 'form1[0].#subform[210].Zip_Postal_Code[3]'
            }
          }
        }
      }.freeze

      def expand(form_data)
        form_data['p13HeaderVeteranSocialSecurityNumber'] = split_ssn(form_data['veteranSocialSecurityNumber'])
        form_data['veteransChildren'] ||= []
        form_data['veteransChildren'] = form_data['veteransChildren'].map { |child| expand_child(child) }
        form_data['childrenLiveTogetherButNotWithSpouse'] =
          to_radio_yes_no_numeric(form_data['childrenLiveTogetherButNotWithSpouse'])
        form_data['custodianFullName'] ||= {}
        form_data['custodianFullName']['first'] = form_data.dig('custodianFullName', 'first')&.titleize
        form_data['custodianFullName']['middle'] = form_data.dig('custodianFullName', 'middle')&.first&.titleize
        form_data['custodianFullName']['last'] = form_data.dig('custodianFullName', 'last')&.titleize
        form_data['custodianAddress'] ||= {}
        form_data['custodianAddress']['postalCode'] =
          split_postal_code(form_data['custodianAddress'])

        form_data
      end

      def expand_child(child = {})
        child_full_name ||= {}
        child_full_name['first'] = child.dig('childFullName', 'first')&.titleize
        child_full_name['middle'] = child.dig('childFullName', 'middle')&.first&.titleize
        child_full_name['last'] = child.dig('childFullName', 'last')&.titleize
        child_status = child['childStatus'] || []
        child.merge({
                      'childFullName' => child_full_name,
                      'childDateOfBirth' => split_date(child['childDateOfBirth']),
                      'childSocialSecurityNumber' => split_ssn(child['childSocialSecurityNumber']),
                      'childStatusBiological' => bool_to_radio(child_status.include?('BIOLOGICAL')),
                      'childStatusAdopted' => bool_to_radio(child_status.include?('ADOPTED')),
                      'childStatusStepchild' => bool_to_radio(child_status.include?('STEPCHILD')),
                      'childStatusMinor' => bool_to_radio(child_status.include?('18-23_YEARS_OLD')),
                      'childStatusDisabled' => bool_to_radio(child_status.include?('SERIOUSLY_DISABLED')),
                      'childStatusMarried' => bool_to_radio(child_status.include?('CHILD_PREVIOUSLY_MARRIED')),
                      'childStatusSupported' =>
                        bool_to_radio(child_status.include?('DOES_NOT_LIVE_WITH_SPOUSE')),
                      'childSupport' => split_currency_amount_sm(child['childSupport'], { 'thousands' => 3 })
                    })
      end

      def bool_to_radio(bool)
        bool || 'Off'
      end

      def to_radio_yes_no_numeric(obj)
        case obj
        when true then 2
        when false then 1
        else 'Off'
        end
      end
    end
  end
end
