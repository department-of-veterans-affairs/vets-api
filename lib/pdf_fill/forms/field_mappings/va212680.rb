# frozen_string_literal: true

module PdfFill
  module Forms
    module FieldMappings
      class Va212680
        KEY = {
          'veteranInformation' => {
            'fullName' => {
              'first' => {
                key: 'form1[0].Page1[0].Veteran_Beneficiarys_FirstName[0]',
                limit: 12
              },
              'middle' => {
                key: 'form1[0].Page1[0].MiddleInitial1[0]',
                limit: 1
              },
              'last' => {
                key: 'form1[0].Page1[0].LastName[0]',
                limit: 18
              }
            },
            'ssn1' => {
              'first' => { key:  'form1[0].Page1[0].Veterans_SocialSecurityNumber_FirstThreeNumbers[0]' },
              'second' => { key: 'form1[0].Page1[0].Veterans_SocialSecurityNumber_SecondTwoNumbers[0]' },
              'third' => { key:  'form1[0].Page1[0].Veterans_SocialSecurityNumber_LastFourNumbers[0]' }
            },
            'ssn2' => {
              'first' => { key: 'form1[0].Page2[0].Veterans_SocialSecurityNumber_FirstThreeNumbers[0]' },
              'second' => { key: 'form1[0].Page2[0].Veterans_SocialSecurityNumber_SecondTwoNumbers[0]' },
              'third' => { key: 'form1[0].Page2[0].Veterans_SocialSecurityNumber_LastFourNumbers[0]' }
            },
            'ssn3' => {
              'first' => { key: 'form1[0].#subform[2].Veterans_SocialSecurityNumber_FirstThreeNumbers[0]' },
              'second' => { key: 'form1[0].#subform[2].Veterans_SocialSecurityNumber_SecondTwoNumbers[0]' },
              'third' => { key: 'form1[0].#subform[2].Veterans_SocialSecurityNumber_LastFourNumbers[0]' }
            },
            'ssn4' => {
              'first' => { key: 'form1[0].#subform[3].Veterans_SocialSecurityNumber_FirstThreeNumbers[1]' },
              'second' => { key: 'form1[0].#subform[3].Veterans_SocialSecurityNumber_SecondTwoNumbers[1]' },
              'third' => { key: 'form1[0].#subform[3].Veterans_SocialSecurityNumber_LastFourNumbers[1]' }
            },

            'vaFileNumber' => {
              key: 'form1[0].Page1[0].VA_FileNumber[0]',
              limit: 9
            },
            'serviceNumber' => {
              key: 'form1[0].Page1[0].Veterans_ServiceNumber[0]',
              limit: 10
            },
            'dateOfBirth' => {
              'month' => { key: 'form1[0].Page1[0].Veterans_DOB_Month[0]' },
              'year' => { key: 'form1[0].Page1[0].Veterans_DOB_Year[0]' },
              'day' => {  key: 'form1[0].Page1[0].Veterans_DOB_Day[0]' }
            },

            'phoneNumber' => {
              'phone_area_code' => { key: 'form1[0].Page1[0].Telephone_Number_Area_Code[0]' },
              'phone_first_three_numbers' => { key: 'form1[0].Page1[0].Telephone_Middle_Three_Numbers[0]' },
              'phone_last_four_numbers' => { key: 'form1[0].Page1[0].Telephone_Last_Four_Numbers[0]' }
            }
          },
          'claimantInformation' => {
            'fullName' => {
              'first' => {
                key: 'form1[0].Page1[0].Claimants_FirstName[0]',
                limit: 12
              },
              'middle' => {
                key: 'form1[0].Page1[0].Claimants_MiddleInitial1[0]',
                limit: 1
              },
              'last' => {
                key: 'form1[0].Page1[0].Claimants_LastName[0]',
                limit: 18
              }
            },
            'ssn' => {
              'first' => { key: 'form1[0].Page1[0].Claimants_SocialSecurityNumber_FirstThreeNumbers[0]' },
              'second' => { key: 'form1[0].Page1[0].Claimants_SocialSecurityNumber_SecondTwoNumbers[0]' },
              'third' => { key: 'form1[0].Page1[0].Claimants_SocialSecurityNumber_LastFourNumbers[0]' }
            },
            'dateOfBirth' => {
              'year' => { key: 'form1[0].Page1[0].Claimants_DOB_Year[0]' },
              'day' => { key: 'form1[0].Page1[0].Claimants_DOB_Day[0]' },
              'month' => { key: 'form1[0].Page1[0].Claimants_DOB_Month[0]' }
            },
            'relationship' => {
              key: 'form1[0].Page1[0].RadioButtonList[0]'
            },

            'address' => {
              'street' => {
                key: 'form1[0].Page1[0].Mailing_Address_NumberAndStreet[0]',
                limit: 30
              },
              'street2' => {
                key: 'form1[0].Page1[0].Mailing_Address_ApartmentOrUnitNumber[0]',
                limit: 5
              },
              'city' => {
                key: 'form1[0].Page1[0].Mailing_Address_City[0]',
                limit: 18
              },
              'state' => {
                key: 'form1[0].Page1[0].Mailing_Address_StateOrProvince[0]',
                limit: 2
              },
              'postalCode' => {
                'firstFive' => {
                  key: 'form1[0].Page1[0].Mailing_Address_ZIPOrPostalCode_FirstFiveNumbers[0]',
                  limit: 5

                },
                'lastFour' => {
                  key: 'form1[0].Page1[0].Mailing_Address_ZIPOrPostalCode_LastFourNumbers[0]',
                  limit: 4
                }
              },
              'country' => {
                key: 'form1[0].Page1[0].Mailing_Address_Country[0]',
                limit: 2
              }
            },
            'phoneNumber' => {
              'phone_area_code' => { key: 'form1[0].Page1[0].Telephone_Number_Area_Code[0]' },
              'phone_first_three_numbers' => { key: 'form1[0].Page1[0].Telephone_Middle_Three_Numbers[0]' },
              'phone_last_four_numbers' => { key: 'form1[0].Page1[0].Telephone_Last_Four_Numbers[0]' }
            },

            'internationalPhoneNumber' => {
              key: 'form1[0].Page1[0].International_Telephone_Number_If_Applicable[0]',
              limit: 14
            },
            'agreeToElectronicCorrespondence' => {
              key: 'form1[0].Page1[0].CheckBox1[0]'
            },
            'email' => {
              'first' => { key: 'form1[0].Page1[0].Email_Address_Optional[0]' },
              'second' => { key: 'form1[0].Page1[0].Email_Address_Optional[1]' }
            }
          },

          # Section III: Benefit Information
          'benefitInformation' => {
            'benefitSelection' => {
              key: 'form1[0].Page1[0].RadioButtonList[1]'
            }
          },
          # Section IV: Additional Information
          'additionalInformation' => {
            'currentlyHospitalized' => {
              key: 'form1[0].Page2[0].RadioButtonList[0]'
            },
            'admissionDate' => {
              'month' => { key: 'form1[0].Page2[0].Date_Admitted_Month[0]' },
              'year' => { key: 'form1[0].Page2[0].Date_Admitted_Year[0]' },
              'day' => {  key: 'form1[0].Page2[0].Date_Admitted_Day[0]' }
            },

            'hospitalName' => {
              key: 'form1[0].Page2[0].NAME_OF_HOSPITAL[0]',
              limit: 50
            },
            'hospitalAddress' => {
              key: 'form1[0].Page2[0].ADDRESS_OF_HOSPITAL[0]'
            }

          },

          # SECTION V: CERTIFICATION AND SIGNATURE
          'veteranSignature' => {
            'signature' => {
              # TODO: Figure out signature standard.
              key: 'form1[0].Page2[0].Digital_Signature[0]',
              limit: 30
            },
            'date' => {
              'month' => { key: 'form1[0].Page2[0].DATE_SIGNED_Month[0]' },
              'year' => { key: 'form1[0].Page2[0].DATE_SIGNED_Year[0]' },
              'day' => {  key: 'form1[0].Page2[0].DATE_SIGNED_Day[0]' }
            }
          }

          # NOTE: Sections VI-VIII (Physician sections) are intentionally left blank
          # These will be filled out manually by the physician on the printed form

        }.freeze
      end
    end
  end
end
