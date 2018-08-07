# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength

module PdfFill
    module Forms
     class Va21p4142 < FormBase

        KEY = {
            'veteranFullName' => {
                'first' => {
                    key: 'F[0].Page_1[0].VeteranFirstName[0]',
                    limit: 12,
                    question_num: 1,
                    question_text: "VETERAN/BENEFICIARY'S FIRST NAME"
                },
                'middle' => {
                    key: 'F[0].Page_1[0].VeteranMiddleInitial1[0]',
                },
                'last' => {
                    key:'F[0].Page_1[0].VeteranLastName[0]',
                    limit: 18,
                    question_num: 1,
                    question_text: "VETERAN/BENEFICIARY'S LAST NAME"
                }
            },
            'veteranSocialSecurityNumber' => {
                'first' => {
                    key: 'F[0].Page_1[0].ClaimantsSocialSecurityNumber_FirstThreeNumbers[0]'
                },
                'second' => {
                    key: 'F[0].Page_1[0].ClaimantsSocialSecurityNumber_SecondTwoNumbers[0]'
                },
                'third' => {
                    key: 'F[0].Page_1[0].ClaimantsSocialSecurityNumber_LastFourNumbers[0]'
                }
            },
            'vaFileNumber' => {
                key: 'F[0].Page_1[0].VAFileNumber[0]'
            },
            'veteranDateOfBirth' => {
                'month' => {
                    key: 'F[0].Page_1[0].DOBmonth[0]'
                },
                'day' => {
                    key: 'F[0].Page_1[0].DOBday[0]'
                },
                'year' => {
                    key: 'F[0].Page_1[0].DOByear[0]'
                }
            },
            'veteranServiceNumber' => {
                key: 'F[0].Page_1[0].VeteransServiceNumber[0]'
            },
            'mailingAddress' => {
                question_num: 6
                question_text: "MAILING ADDRESS",

                'veteranAddressLine1' => {
                    key: 'F[0].Page_1[0].CurrentMailingAddress_NumberAndStreet[0]',
                    limit: 30,
                    question_num: 6,
                    question_suffix: 'A',
                    question_text: 'Number and Street'
                },
                'apartmentOrUnitNumber' => {
                    key: 'F[0].Page_1[0].CurrentMailingAddress_ApartmentOrUnitNumber[0]',
                    limit: 5,
                    question_num: 6,
                    question_suffix: 'B',
                    question_text: 'Apartment or Unit Number'
                },
                'city' => {
                    key: 'F[0].Page_1[0].CurrentMailingAddress_City[0]',
                    limit: 18,
                    question_num: 6,
                    question_suffix: 'C',
                    question_text: 'City'
                },
                'stateOrProvince' => {
                    key: 'F[0].Page_1[0].CurrentMailingAddress_StateOrProvince[0]'
                },
                'country' => {
                    key: 'F[0].Page_1[0].CurrentMailingAddress_Country[0]'
                    limit: 2
                },
                'zipOrPostalCode' => {
                    'firstFive' => {
                        key: 'F[0].Page_1[0].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]'
                    },
                    'lastFour' => {
                        key: 'F[0].Page_1[0].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]'
                    } 
                }
            }
            'emailAddress' => {
                key: 'F[0].Page_1[0].EMAIL[0]'
            },
            'phoneNumber' => {
                key: 'F[0].Page_1[0].EMAIL[1]'
            },
            # Patient other than veteran not currently in scope.
            # 'patientIdentification' => {
            #     'patientFirstName' => {
            #         key: 'F[0].Page_1[0].VeteranFirstName[1]',
            #         limit: 12,
            #         question_num: 9,
            #         question_suffix: 'A',
            #         question_text: "PATIENT'S FIRST NAME"
            #     },
            #     'patientMiddleInitial' => {
            #         key: 'F[0].Page_1[0].VeteranMiddleInitial1[1]'
            #     },
            #     'patientLastName' => {
            #         key: 'F[0].Page_1[0].VeteranLastName[1]',
            #         limit: 18,
            #         question_num: 9,
            #         question_suffix: 'B',
            #         question_text: "PATIENT'S LAST NAME"
            #     }
            #     'veteranSocialSecurityNumber1' => {
            #         'first' => {
            #             key: 'F[0].Page_1[0].ClaimantsSocialSecurityNumber_FirstThreeNumbers[1]'
            #         },
            #         'second' => {
            #             key: 'F[0].Page_1[0].ClaimantsSocialSecurityNumber_SecondTwoNumbers[1]'
            #         },
            #         'third' => {
            #             key: 'F[0].Page_1[0].ClaimantsSocialSecurityNumber_LastFourNumbers[1]'
            #         }
            #     },
            #     'vaFileNumber1' => {
            #         key: 'F[0].Page_1[0].VAFileNumber[1]'
            #     }
            # },
            'veteranSocialSecurityNumber2' => {
                'first' => {
                    key: 'F[0].#subform[1].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
                },
                'second' => {
                    key: 'F[0].#subform[1].VeteransSocialSecurityNumber_SecondTwoNumbers[0]'
                },
                'third' => {
                    key: 'F[0].#subform[1].VeteransSocialSecurityNumber_LastFourNumbers[0]'
                }
            },
            'limitedConsent' => {
                key: 'F[0].#subform[1].InformationIsLimitedToWhatIsWrittenInThisSpace[0]'
            },
            'signature' => {
                key: 'F[0].#subform[1].CLAIMANT_SIGNATURE[0]'
            },
            'signatureDate' => {
                key: 'F[0].#subform[1].DateSigned_Month_Day_Year[0]'
            },
            'signature1' => {
                key: 'F[0].#subform[1].PrintedNameOfPersonAuthorizingDisclosure[0]'
            }, 
            'relationshipToVeteran_Claimant' => {
                key: 'F[0].#subform[1].RelationshipToVeteran_Claimant[0]'
            }

        }

        def split_ssn
            ssn = @form_data['veteranSocialSecurityNumber']
            return if ssn.blank?
            split_ssn = {
              'first' => ssn[0..2],
              'second' => ssn[3..4],
              'third' => ssn[5..8]
            }
    
            ['','1','2'].each do |suffix|
              @form_data["veteranSocialSecurityNumber#{suffix}"] = split_ssn
            end
    
            split_ssn
        end

        # VA file number can be up to 10 digits long; An optional leading 'c' or 'C' followed by
        # 7-9 digits. The file number field on the 4142 form has space for 9 characters so trim the
        # potential leading 'c' to ensure the file number will fit into the form without overflow.
        def extract_va_file_number(va_file_number)
            return va_file_number if va_file_number.blank? || va_file_number.length < 10

            va_file_number.sub(/^[Cc]/, '')

        end


        def merge_fields
            # make changes to the form before final processing
            split_ssn

            ['','1'].each do |suffix|
            @form_data["vaFileNumber#{suffix}"] = extract_va_file_number(@form_data["vaFileNumber#{suffix}"])

            expand_signature(@form_data['veteranFullName'])

            @form_data
        end
    end
  end
end