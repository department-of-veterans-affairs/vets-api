# frozen_string_literal: true

require 'survivors_benefits/pdf_fill/section'

require_relative '../../constants'

module SurvivorsBenefits
  module PdfFill
    # Section 6: Children of the Veteran Information
    class Section6 < Section
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
        'veteransChildOne' => {
          first_key: 'childFullName',
          'childFullName' => {
            'first' => {
              limit: 12,
              question_num: 6,
              question_suffix: 'B',
              question_label: "Child's First Name",
              question_text: 'CHILD\'S FIRST NAME',
              key: 'form1[0].#subform[210].Childs_FirstName[2]'
            },
            'middle' => {
              limit: 1,
              question_num: 6,
              question_suffix: 'B',
              key: 'form1[0].#subform[210].Childs_MiddleInitial1[2]'
            },
            'last' => {
              limit: 18,
              question_num: 6,
              question_suffix: 'B',
              question_label: "Child's Last Name",
              question_text: 'CHILD\'S LAST NAME',
              key: 'form1[0].#subform[210].Childs_LastName[2]'
            }
          },
          'childDateOfBirth' => {
            'month' => {
              key: 'form1[0].#subform[210].Date_Month[9]'
            },
            'day' => {
              key: 'form1[0].#subform[210].Date_Day[9]'
            },
            'year' => {
              key: 'form1[0].#subform[210].Date_Year[9]'
            }
          },
          'childSocialSecurityNumber' => {
            'first' => {
              key: 'form1[0].#subform[210].Childs_SocialSecurityNumber_FirstThreeNumbers[1]'
            },
            'second' => {
              key: 'form1[0].#subform[210].Childs_SocialSecurityNumber_SecondTwoNumbers[1]'
            },
            'third' => {
              key: 'form1[0].#subform[210].Childs_SocialSecurityNumber_LastFourNumbers[1]'
            }
          },
          'childPlaceOfBirth' => {
            limit: 28,
            question_num: 6,
            question_suffix: 'E',
            question_label: 'Child\'s Place Of Birth (City/State or Country)',
            question_text: 'CHILD\'S PLACE OF BIRTH (CITY/STATE OR COUNTRY)',
            key: 'form1[0].#subform[210].Place_Of_Birth_City_State_Or_Country[2]'
          },
          'childStatusBiological' => {
            key: 'form1[0].#subform[210].JF06[2]'
          },
          'childStatusAdopted' => {
            key: 'form1[0].#subform[210].JF14[2]'
          },
          'childStatusStepchild' => {
            key: 'form1[0].#subform[210].JF08[2]'
          },
          'childStatusMinor' => {
            key: 'form1[0].#subform[210].JF12[2]'
          },
          'childStatusDisabled' => {
            key: 'form1[0].#subform[210].JF10[2]'
          },
          'childStatusMarried' => {
            key: 'form1[0].#subform[210].JF18[2]'
          },
          'childStatusSupported' => {
            key: 'form1[0].#subform[210].JF16[2]'
          },
          'childSupport' => {
            'thousands' => {
              key: 'form1[0].#subform[210].Monthly_Amount_Contribution[1]'
            },
            'dollars' => {
              key: 'form1[0].#subform[210].Monthly_Amount_Contribution[0]'
            }
          }
        },
        'veteransChildTwo' => {
          first_key: 'childFullName',
          'childFullName' => {
            'first' => {
              limit: 12,
              question_num: 6,
              question_suffix: 'G',
              question_label: "Child's First Name",
              question_text: 'CHILD\'S FIRST NAME',
              key: 'form1[0].#subform[210].Childs_FirstName[1]'
            },
            'middle' => {
              limit: 1,
              question_num: 6,
              question_suffix: 'G',
              key: 'form1[0].#subform[210].Childs_MiddleInitial1[1]'
            },
            'last' => {
              limit: 18,
              question_num: 6,
              question_suffix: 'G',
              question_label: "Child's Last Name",
              question_text: 'CHILD\'S LAST NAME',
              key: 'form1[0].#subform[210].Childs_LastName[1]'
            }
          },
          'childDateOfBirth' => {
            'month' => {
              key: 'form1[0].#subform[210].Date_Month[10]'
            },
            'day' => {
              key: 'form1[0].#subform[210].Date_Day[10]'
            },
            'year' => {
              key: 'form1[0].#subform[210].Date_Year[10]'
            }
          },
          'childSocialSecurityNumber' => {
            'first' => {
              key: 'form1[0].#subform[210].Childs_SocialSecurityNumber_FirstThreeNumbers[2]'
            },
            'second' => {
              key: 'form1[0].#subform[210].Childs_SocialSecurityNumber_SecondTwoNumbers[2]'
            },
            'third' => {
              key: 'form1[0].#subform[210].Childs_SocialSecurityNumber_LastFourNumbers[2]'
            }
          },
          'childPlaceOfBirth' => {
            limit: 28,
            question_num: 6,
            question_suffix: 'J',
            question_label: 'Child\'s Place Of Birth (City/State or Country)',
            question_text: 'CHILD\'S PLACE OF BIRTH (CITY/STATE OR COUNTRY)',
            key: 'form1[0].#subform[210].Place_Of_Birth_City_State_Or_Country[1]'
          },
          'childStatusBiological' => {
            key: 'form1[0].#subform[210].JF06[1]'
          },
          'childStatusAdopted' => {
            key: 'form1[0].#subform[210].JF14[1]'
          },
          'childStatusStepchild' => {
            key: 'form1[0].#subform[210].JF08[1]'
          },
          'childStatusMinor' => {
            key: 'form1[0].#subform[210].JF12[1]'
          },
          'childStatusDisabled' => {
            key: 'form1[0].#subform[210].JF10[1]'
          },
          'childStatusMarried' => {
            key: 'form1[0].#subform[210].JF18[1]'
          },
          'childStatusSupported' => {
            key: 'form1[0].#subform[210].JF16[1]'
          },
          'childSupport' => {
            'thousands' => {
              key: 'form1[0].#subform[210].Total_Annual_Earnings_Amount[2]'
            },
            'dollars' => {
              key: 'form1[0].#subform[210].Total_Annual_Earnings_Amount[3]'
            }
          }
        },
        'veteransChildThree' => {
          first_key: 'childFullName',
          'childFullName' => {
            'first' => {
              limit: 12,
              question_num: 6,
              question_suffix: 'L',
              question_label: "Child's First Name",
              question_text: 'CHILD\'S FIRST NAME',
              key: 'form1[0].#subform[210].Childs_FirstName[0]'
            },
            'middle' => {
              limit: 1,
              question_num: 6,
              question_suffix: 'L',
              key: 'form1[0].#subform[210].Childs_MiddleInitial1[0]'
            },
            'last' => {
              limit: 18,
              question_num: 6,
              question_suffix: 'L',
              question_label: "Child's Last Name",
              question_text: 'CHILD\'S LAST NAME',
              key: 'form1[0].#subform[210].Childs_LastName[0]'
            }
          },
          'childDateOfBirth' => {
            'month' => {
              key: 'form1[0].#subform[210].Date_Month[8]'
            },
            'day' => {
              key: 'form1[0].#subform[210].Date_Day[8]'
            },
            'year' => {
              key: 'form1[0].#subform[210].Date_Year[8]'
            }
          },
          'childSocialSecurityNumber' => {
            'first' => {
              key: 'form1[0].#subform[210].Childs_SocialSecurityNumber_FirstThreeNumbers[0]'
            },
            'second' => {
              key: 'form1[0].#subform[210].Childs_SocialSecurityNumber_SecondTwoNumbers[0]'
            },
            'third' => {
              key: 'form1[0].#subform[210].Childs_SocialSecurityNumber_LastFourNumbers[0]'
            }
          },
          'childPlaceOfBirth' => {
            limit: 28,
            question_num: 6,
            question_suffix: 'O',
            question_label: 'Child\'s Place Of Birth (City/State or Country)',
            question_text: 'CHILD\'S PLACE OF BIRTH (CITY/STATE OR COUNTRY)',
            key: 'form1[0].#subform[210].Place_Of_Birth_City_State_Or_Country[0]'
          },
          'childStatusBiological' => {
            key: 'form1[0].#subform[210].JF06[0]'
          },
          'childStatusAdopted' => {
            key: 'form1[0].#subform[210].JF14[0]'
          },
          'childStatusStepchild' => {
            key: 'form1[0].#subform[210].JF08[0]'
          },
          'childStatusMinor' => {
            key: 'form1[0].#subform[210].JF12[0]'
          },
          'childStatusDisabled' => {
            key: 'form1[0].#subform[210].JF10[0]'
          },
          'childStatusMarried' => {
            key: 'form1[0].#subform[210].JF18[0]'
          },
          'childStatusSupported' => {
            key: 'form1[0].#subform[210].JF16[0]'
          },
          'childSupport' => {
            'thousands' => {
              key: 'form1[0].#subform[210].Total_Annual_Earnings_Amount[1]'
            },
            'dollars' => {
              key: 'form1[0].#subform[210].Total_Annual_Earnings_Amount[0]'
            }
          }
        },
        'childrenLiveTogetherButNotWithSpouse' => {
          key: 'form1[0].#subform[210].RadioButtonList[23]'
        },
        'custodianFullName' => {
          'first' => {
            limit: 12,
            question_num: 6,
            question_suffix: 'R',
            question_label: 'Custodian\'s First Name',
            question_text: 'CUSTODIAN\'S FIRST NAME',
            key: 'form1[0].#subform[210].Custodians_FirstName[0]'
          },
          'middle' => {
            limit: 1,
            question_num: 6,
            question_suffix: 'R',
            key: 'form1[0].#subform[210].Custodians_MiddleInitial1[0]'
          },
          'last' => {
            limit: 18,
            question_num: 6,
            question_suffix: 'R',
            question_label: "Custodian's Last Name",
            question_text: 'CUSTODIAN\'S LAST NAME',
            key: 'form1[0].#subform[210].Custodians_LastName[0]'
          }
        },
        'custodianAddress' => {
          'street' => {
            limit: 30,
            question_num: 6,
            question_suffix: 'R',
            question_label: 'Mailing Address Number And Street',
            question_text: 'MAILING ADDRESS NUMBER AND STREET',
            key: 'form1[0].#subform[210].NumberStreet[2]'
          },
          'street2' => {
            limit: 5,
            question_num: 6,
            question_suffix: 'R',
            question_label: 'Mailing Address Apt/Unit',
            question_text: 'MAILING ADDRESS APT/UNIT',
            key: 'form1[0].#subform[210].Apt_Or_Unit_Number[1]'
          },
          'city' => {
            limit: 18,
            question_num: 6,
            question_suffix: 'R',
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
              question_num: 6,
              question_suffix: 'R',
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
        veterans_children = form_data['veteransChildren'].map { |child| expand_child(child) }
        form_data['veteransChildOne'] = veterans_children.first || {}
        form_data['veteransChildTwo'] = veterans_children.second || {}
        form_data['veteransChildThree'] = veterans_children.third || {}
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
