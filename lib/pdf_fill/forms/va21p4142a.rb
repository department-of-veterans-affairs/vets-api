# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
require 'pdf_fill/forms/form_helper'

module PdfFill
    module Forms
     class Va21p4142a < FormBase

        KEY = {
            'veteranFullName' => {
                'first' => {
                    key: '',
                    limit: 12,
                    question_num: 1,
                    question_text: "VETERAN/BENEFICIARY'S FIRST NAME"
                },
                'middle' => {
                    key: '',
                },
                'last' => {
                    key:'',
                    limit: 18,
                    question_num: 1,
                    question_text: "VETERAN/BENEFICIARY'S LAST NAME"
                }
            },
            'veteranSocialSecurityNumber' => {
                'first' => {
                    key: ''
                },
                'second' => {
                    key: ''
                },
                'third' => {
                    key: ''
                }
            },
            'vaFileNumber' => {
                key: ''
            },
            'veteranDateOfBirth' => {
                'month' => {
                    key: ''
                },
                'day' => {
                    key: ''
                },
                'year' => {
                    key: ''
                }
            },
            'veteranServiceNumber' => {
                key: ''
            },
            'providers' => {
                limit: 5,
                first_key: 'providerOrFacilityName',
                            
                'providerOrFacilityName' => {
                    key: 'form1[0].#subform[0].FirstandLastNamrofMedicalTreatmentProviderOrFacilityName[1]'
                },
                'datesOfTreatment' => {
                    limit: 2,
                    'fromDate' => {
                        key: ''
                    },
                    'toDate' => {
                        key: ''
                    }                
                },
                'numberAndStreet' => {
                    limit: 30,
                    key: ''
                },
                'apartmentOrUnitNumber' => {
                    limit: 5,
                    key: ''
                },
                'city' => {
                    limit: 18,
                    key:''
                },
                'stateOrProvince' => {
                    key:''
                },
                'country' => {
                    key:''
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
        }.freeze
        # rubocop:enable Metrics/LineLength
        
        # rubocop:disable Metrics/MethodLength
        def merge_fields
            
            # ['','1','2'].each do |suffix|
            #     @form_data["veteranSocialSecurityNumber#{suffix}"] = FormHelper.split_ssn(@form_data['veteranSocialSecurityNumber'])
            # end

            # @form_data['providers'].with_index do |provider, iterator|
            #     @form_data["provider#{iterator}"] = FormHelper.split_provider(@form_data)
            # end


            # @form_data["vaFileNumber"] = FormHelper.extract_va_file_number(@form_data["vaFileNumber"])

            # expand_signature(@form_data['veteranFullName'])

            @form_data
        end
        # rubocop:enable Metrics/MethodLength
     end
    end
end