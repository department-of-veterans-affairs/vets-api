module PdfFill
  module Forms
    # TODO bring back workflow require statements
    class VA21P530 < FormBase
      KEY = {
        'veteranFullName' => {
          'first' => {
            key: 'form1[0].#subform[36].VeteransFirstName[0]',
            limit: 12,
            question: "1. DECEASED VETERAN'S FIRST NAME"
          },
          'middleInitial' => {
            key: 'form1[0].#subform[36].VeteransMiddleInitial1[0]'
          },
          'last' => {
            key: 'form1[0].#subform[36].VeteransLastName[0]',
            limit: 18,
            question: "1. DECEASED VETERAN'S LAST NAME"
          }
        },
        'vaFileNumber' => {
          key: 'form1[0].#subform[36].VAFileNumber[0]'
        },
        'claimantEmail' => {
          key: 'form1[0].#subform[36].PreferredE_MailAddress[0]',
          limit: 31,
          question: '7. PREFERRED E-MAIL ADDRESS'
        },
        'claimantFullName' => {
          'first' => {
            key: 'form1[0].#subform[36].ClaimantsFirstName[0]',
            limit: 12,
            question: "4. CLAIMANT'S FIRST NAME"
          },
          'middleInitial' => {
            key: 'form1[0].#subform[36].ClaimantsMiddleInitial1[0]'
          },
          'last' => {
            key: 'form1[0].#subform[36].ClaimantsLastName[0]',
            limit: 18,
            question: "4. CLAIMANT'S LAST NAME"
          }
        },
        'claimantAddress' => {
          'street' => {
            key: 'form1[0].#subform[36].CurrentMailingAddress_NumberAndStreet[0]',
            limit: 30,
            question: '5. CURRENT MAILING ADDRESS (No. & Street)'
          },
          'aptNum' => {
            key: 'form1[0].#subform[36].CurrentMailingAddress_ApartmentOrUnitNumber[0]'
          },
          'city' => {
            key: 'form1[0].#subform[36].CurrentMailingAddress_City[0]',
            limit: 18,
            question: '5. CURRENT MAILING ADDRESS (City)'
          },
          'state' => {
            key: 'form1[0].#subform[36].CurrentMailingAddress_StateOrProvince[0]'
          },
          'country' => {
            key: 'form1[0].#subform[36].CurrentMailingAddress_Country[0]'
          },
          'postalCode1' => {
            key: 'form1[0].#subform[36].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]'
          },
          'postalCode2' => {
            key: 'form1[0].#subform[36].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]'
          }
        },
        'relationship' => {
          'checkbox' => {
            'spouse' => {
              key: 'form1[0].#subform[36].CheckBox1[0]'
            }
            'child' => {
              key: 'form1[0].#subform[36].CheckBox2[0]'
            },
            'executor' => {
              key: 'form1[0].#subform[36].CheckBox4[0]'
            },
            'other' => {
              key: 'form1[0].#subform[36].CheckBox5[0]'
            },
            'parent' => {
              key: 'form1[0].#subform[36].CheckBox3[0]'
            }
          },
          'other' => {
            limit: 58,
            question: "8. RELATIONSHIP OF CLAIMANT TO DECEASED VETERAN"
            key: 'form1[0].#subform[36].OTHER_SPECIFY[0]'
          }
        },
        'claimantPhone' => {
          'first' => {
            key: 'form1[0].#subform[36].PreferredTelephoneNumber_AreaCode[0]'
          },
          'second' => {
            key: 'form1[0].#subform[36].PreferredTelephoneNumber_FirstThreeNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[36].PreferredTelephoneNumber_LastFourNumbers[0]'
          }
        },
        'veteranSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[36].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'form1[0].#subform[36].VeteransSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[36].VeteransSocialSecurityNumber_LastFourNumbers[0]'
          }
        }
      }

      def split_ssn
        ssn = @form_data['veteranSocialSecurityNumber']
        return if ssn.blank?

        @form_data['veteranSocialSecurityNumber'] = {
          'first' => ssn[0..2],
          'second' => ssn[3..4],
          'third' => ssn[5..8]
        }
      end

      def split_phone(hash, key)
        phone = hash[key]
        return if phone.blank?

        hash[key] = {
          'first' => phone[0..2],
          'second' => phone[3..5],
          'third' => phone[6..9]
        }
      end

      def extract_middle_i(hash, key)
        full_name = hash[key]
        return if full_name.blank?

        middle_name = full_name['middle']
        return if middle_name.blank?
        full_name['middleInitial'] = middle_name[0]

        hash[key]
      end

      def merge_fields
        %w(veteranFullName claimantFullName).each do |attr|
          extract_middle_i(@form_data, attr)
        end

        split_ssn

        split_phone(@form_data, 'claimantPhone')

        @form_data
      end
    end
  end
end
