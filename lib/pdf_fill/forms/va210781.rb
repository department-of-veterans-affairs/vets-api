module PdfFill
  module Forms
    class Va210781a < FormBase
      include FormHelper

      KEY = {
        'veteranFullName' => {
          'first' => {
            key: 'form1[0].#subform[0].ClaimantsFirstName[0]',
            limit: 12,
            question_num: 1,
            question_suffix: 'A',
            question_text: "VETERAN/BENEFICIARY'S FIRST NAME"
          },
          'middleInitial' => {
            key: 'form1[0].#subform[0].ClaimantsMiddleInitial1[0]'
          },
          'last' => {
            key: 'form1[0].#subform[0].ClaimantsLastName[0]',
            limit: 18,
            question_num: 1,
            question_suffix: 'B',
            question_text: "VETERAN/BENEFICIARY'S LAST NAME"
          }
        },
        'veteranSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[0].ClaimantsSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'form1[0].#subform[0].ClaimantsSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[0].ClaimantsSocialSecurityNumber_LastFourNumbers[0]'
            },
          },
          'veteranSocialSecurityNumber1' => {
            'first' => {
              key: 'form1[0].#subform[1].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
            },
            'second' => {
              key: 'form1[0].#subform[1].VeteransSocialSecurityNumber_SecondTwoNumbers[0]'
            },
            'third' => {
              key: 'form1[0].#subform[1].VeteransSocialSecurityNumber_SecondTwoNumbers[0]'
              },
            },
            'veteranSocialSecurityNumber2' => {
              'first' => {
                key: 'form1[0].#subform[2].VeteransSocialSecurityNumber_FirstThreeNumbers[1]'
              },
              'second' => {
                key: 'form1[0].#subform[2].VeteransSocialSecurityNumber_SecondTwoNumbers[1]'
              },
              'third' => {
                key: 'form1[0].#subform[2].VeteransSocialSecurityNumber_LastFourNumbers[1]'
                },
              },
            'vaFileNumber' => {
              key: 'form1[0].#subform[0].VAFileNumber[0]'
            },
            'veteranDateOfBirth' => {
              'month' => {
                key: 'form1[0].#subform[0].DOBmonth[0]'
              },
              'day' => {
                key: 'form1[0].#subform[0].DOBday[0]'
              },
              'year' => {
                key: 'form1[0].#subform[0].DOByear[0]'
              }
            },
            'veteranServiceNumber' => {
              key: 'form1[0].#subform[0].VeteransServiceNumber[0]'
            },
            'email' => {
              key: 'form1[0].#subform[0].PreferredEmail[0]'
            },
            'veteranPhone' => {
              key: 'form1[0].#subform[0].PreferredEmail[1]'
            },
            'veteranSecondaryPhone' => {
              key: 'form1[0].#subform[0].PreferredEmail[2]'
            },
            'signature' => {
              key: 'form1[0].#subform[2].Signature[0]'
            },
            'signatureDate' => {
              key: 'form1[0].#subform[2].Date11[0]'
            }
            # 'incident' => {
            #   limit: 2,
            #   first_key: 'incidentDescription',
            #   question_text: 'INCIDENTS',
            #   question_num: 8,
            #   'incidentDate' => {
            #     'month' => {
            #       key: 'form1[0].#subform[0].DOBmonth[1]'
            #     },
            #     'day' => {
            #       key: 'form1[0].#subform[0].DOBday[1]'
            #     },
            #     'year' => {
            #       key: 'form1[0].#subform[0].DOByear[1]'
            #     }
            #   },
            #   'unitAssignedDates' => {
            #     'fromMonth' => {
            #       key: 'form1[0].#subform[0].DOBmonth[2]'
            #     },
            #     'fromDay' => {
            #       key: 'form1[0].#subform[0].DOBday[2]'
            #     },
            #     'fromYear' => {
            #       key: 'form1[0].#subform[0].DOByear[2]'
            #     },
            #     'toMonth' => {
            #       key: 'form1[0].#subform[0].DOBmonth[3]'
            #     },
            #     'toDay' => {
            #       key: 'form1[0].#subform[0].DOBday[3]'
            #     },
            #     'toYear' => {
            #       key: 'form1[0].#subform[0].DOByear[3]'
            #     }
            #   },
            #   'incidentLocation' => {
            #     question_num: 8,
            #     limit: 3,
            #     first_key: 'row0',
            #     'row0' => {
            #       key: 'form1[0].#subform[0].TextField1[0]'
            #     },
            #     'row1' => {
            #       key: 'form1[0].#subform[0].TextField1[1]'
            #     },
            #     'row2' => {
            #       key: 'form1[0].#subform[0].TextField1[2]'
            #     }
            #   },
            #   'unitAssigned' => {
            #     question_num: 8,
            #     limit: 3,
            #     'row0' => {
            #       key: 'form1[0].#subform[0].TextField1[3]'
            #       limit: 30
            #     },
            #     'row1' => {
            #       key: 'form1[0].#subform[0].TextField1[4]'
            #       limit: 30
            #     },
            #     'row2' => {
            #       key: 'form1[0].#subform[0].TextField1[5]'
            #       limit: 30
            #     }
            #   },
            #   'incidentDescription' => {
            #     key: 'form1[0].#subform[0].Description[0]'
            #   },
            #   'medalsCitations': {
            #     key: 'form1[0].#subform[0].Medals[0]'
            #   },
            #   'personInvolved' => {
            #     'name' => {
            #       'first' => {
            #         key: 'form1[0].#subform[1].ClaimantsFirstName[1]'
            #       },
            #       'middleInitial' => {
            #         key: 'form1[0].#subform[1].ClaimantsMiddleInitial1[1]'
            #       },
            #       'last' => {
            #         key: 'form1[0].#subform[1].ClaimantsLastName[1]'
            #       }
            #     },
            #     'rank' => {
            #         key: 'form1[0].#subform[1].RANK4B[0]'
            #     },
            #     'injuryDeathDate' => {
            #       'month' => {
            #         key: 'form1[0].#subform[1].DOBmonth[4]'
            #       },
            #       'day' => {
            #         key: 'form1[0].#subform[1].DOBday[4]'
            #       },
            #       'year' => {
            #         key: 'form1[0].#subform[1].DOByear[4]'
            #       }
            #     },
            #     'injuryDeath' => {
            #       # TODO: DON'T KNOW HOW TO DO ENUM
            #     },
            #     'unitAssigned' => {
            #       question_num: 8,
            #       limit: 3,
            #       'row0' => {
            #         key: 'form1[0].#subform[1].TextField1[6]'
            #         limit: 30
            #       },
            #       'row1' => {
            #         key: 'form1[0].#subform[1].TextField1[7]'
            #         limit: 30
            #       },
            #       'row2' => {
            #         key: 'form1[0].#subform[1].TextField1[8]'
            #         limit: 30
            #       }
            #     }
            #
            #   }
            # },
          }
      }.freeze

      def expand_veteran_full_name
        @form_data['veteranFullName'] = extract_middle_i(@form_data, 'veteranFullName')
      end

      def expand_ssn
        ssn = @form_data['veteranSocialSecurityNumber']
        return if ssn.blank?
        ['', '1', '2'].each do |suffix|
          @form_data["veteranSocialSecurityNumber#{suffix}"] = split_ssn(ssn)
        end
      end

      def expand_veteran_dob
        veteran_date_of_birth = @form_data['veteranDateOfBirth']
        return if veteran_date_of_birth.blank?
        @form_data['veteranDateOfBirth'] = split_date(veteran_date_of_birth)
      end

      def merge_fields
        expand_veteran_full_name
        expand_ssn
        expand_veteran_dob

        expand_signature(@form_data['veteranFullName'])
        @form_data['signature'] = '/es/ ' + @form_data['signature']

        @form_data

      end

    end
  end
end
