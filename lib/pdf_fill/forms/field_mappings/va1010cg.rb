# frozen_string_literal: true

module PdfFill
  module Forms
    module FieldMappings
      # rubocop:disable Metrics/ClassLength
      class Va1010cg
        PDF_INPUT_LOCATIONS = OpenStruct.new(
          veteran: {
            name: {
              last: 'form1[0].#subform[15].LastName[0]',
              first: 'form1[0].#subform[15].FirstName[0]',
              middle: 'form1[0].#subform[15].MiddleName[0]',
              suffix: 'form1[0].#subform[15].Suffix[0]'
            },
            ssn: 'form1[0].#subform[15].SSN_TaxID[0]',
            dob: 'form1[0].#subform[15].DateOfBirth[0]',
            gender: 'form1[0].#subform[15].RadioButtonList[0]', # "2" | "3" | "Off"
            address: {
              street: 'form1[0].#subform[15].StreetAddress[0]',
              city: 'form1[0].#subform[15].City[0]',
              county: 'form1[0].#subform[15].County[0]',
              state: 'form1[0].#subform[15].State[0]',
              zip: 'form1[0].#subform[15].Zip[0]'
            },
            primary_phone: 'form1[0].#subform[15].PrimaryPhone[0]',
            alternative_phone: 'form1[0].#subform[15].AltPhone[0]',
            email: 'form1[0].#subform[15].Email[0]',
            planned_clinic: 'form1[0].#subform[15].NameVAMedicalCenter[0]',
            signature: {
              name: 'form1[0].#subform[15].Signature[0]',
              date: 'form1[0].#subform[15].DateSigned[0]'
            }
          },
          primaryCaregiver: {
            name: {
              last: 'form1[0].#subform[16].LastName[1]',
              first: 'form1[0].#subform[16].FirstName[1]',
              middle: 'form1[0].#subform[16].MiddleName[1]',
              suffix: 'form1[0].#subform[16].Suffix[1]'
            },
            ssn: 'form1[0].#subform[16].SSN_TaxID[1]',
            dob: 'form1[0].#subform[16].DateOfBirth[1]',
            gender: 'form1[0].#subform[16].RadioButtonList[1]', # "2" | "3" | "Off"
            address: {
              street: 'form1[0].#subform[16].StreetAddress[1]',
              city: 'form1[0].#subform[16].City[1]',
              county: 'form1[0].#subform[16].County[1]',
              state: 'form1[0].#subform[16].State[1]',
              zip: 'form1[0].#subform[16].Zip[1]'
            },
            mailingAddress: {
              street: 'form1[0].#subform[16].MailingStreetAddress[0]',
              city: 'form1[0].#subform[16].City[2]',
              county: 'form1[0].#subform[16].County[2]',
              state: 'form1[0].#subform[16].State[2]',
              zip: 'form1[0].#subform[16].Zip[2]'
            },
            primary_phone: 'form1[0].#subform[16].PrimaryPhone[1]',
            alternative_phone: 'form1[0].#subform[16].AltPhone[1]',
            email: 'form1[0].#subform[16].Email[1]',
            vet_relationship: 'form1[0].#subform[16].Relationship[0]',
            signature: {
              name: 'form1[0].#subform[16].Signature[1]',
              date: 'form1[0].#subform[16].DateSigned[1]'
            }
          },
          secondaryCaregiverOne: {
            name: {
              last: 'form1[0].#subform[17].LastName[2]',
              first: 'form1[0].#subform[17].FirstName[2]',
              middle: 'form1[0].#subform[17].MiddleName[2]',
              suffix: 'form1[0].#subform[17].Suffix[2]'
            },
            ssn: 'form1[0].#subform[17].SSN_TaxID[2]',
            dob: 'form1[0].#subform[17].DateOfBirth[2]',
            gender: 'form1[0].#subform[17].RadioButtonList[2]', # "2" | "3" | "Off"
            address: {
              street: 'form1[0].#subform[17].StreetAddress[2]',
              city: 'form1[0].#subform[17].City[3]',
              county: 'form1[0].#subform[17].County[3]',
              state: 'form1[0].#subform[17].State[3]',
              zip: 'form1[0].#subform[17].Zip[3]'
            },
            mailingAddress: {
              street: 'form1[0].#subform[17].MailingStreetAddress[1]',
              city: 'form1[0].#subform[17].City[4]',
              county: 'form1[0].#subform[17].County[4]',
              state: 'form1[0].#subform[17].State[4]',
              zip: 'form1[0].#subform[17].Zip[4]'
            },
            primary_phone: 'form1[0].#subform[17].PrimaryPhone[2]',
            alternative_phone: 'form1[0].#subform[17].AltPhone[2]',
            email: 'form1[0].#subform[17].Email[2]',
            vet_relationship: 'form1[0].#subform[17].Relationship[1]',
            signature: {
              name: 'form1[0].#subform[17].Signature[2]',
              date: 'form1[0].#subform[17].DateSigned[2]'
            }
          },
          secondaryCaregiverTwo: {
            name: {
              last: 'form1[0].#subform[18].LastName[3]',
              first: 'form1[0].#subform[18].FirstName[3]',
              middle: 'form1[0].#subform[18].MiddleName[3]',
              suffix: 'form1[0].#subform[18].Suffix[3]'
            },
            ssn: 'form1[0].#subform[18].SSN_TaxID[3]',
            dob: 'form1[0].#subform[18].DateOfBirth[3]',
            gender: 'form1[0].#subform[18].RadioButtonList[3]', # "2" | "3" | "Off"
            address: {
              street: 'form1[0].#subform[18].StreetAddress[3]',
              city: 'form1[0].#subform[18].City[5]',
              county: 'form1[0].#subform[18].County[5]',
              state: 'form1[0].#subform[18].State[5]',
              zip: 'form1[0].#subform[18].Zip[5]'
            },
            mailingAddress: {
              street: 'form1[0].#subform[18].MailingStreetAddress[2]',
              city: 'form1[0].#subform[18].City[6]',
              county: 'form1[0].#subform[18].County[6]',
              state: 'form1[0].#subform[18].State[6]',
              zip: 'form1[0].#subform[18].Zip[6]'
            },
            primary_phone: 'form1[0].#subform[18].PrimaryPhone[3]',
            alternative_phone: 'form1[0].#subform[18].AltPhone[3]',
            email: 'form1[0].#subform[18].Email[3]',
            vet_relationship: 'form1[0].#subform[18].Relationship[2]',
            signature: {
              name: 'form1[0].#subform[18].Signature[3]',
              date: 'form1[0].#subform[18].DateSigned[3]'
            }
          }
        )

        KEY = {
          'helpers' => {
            'veteran' => {
              'address' => {
                'street' => {
                  key: PDF_INPUT_LOCATIONS.veteran[:address][:street],
                  limit: 80,
                  question_num: 108,
                  question_text: 'VETERAN/SERVICEMEMBER > Address > Street'
                }
              },
              'gender' => {
                key: PDF_INPUT_LOCATIONS.veteran[:gender]
              },
              'signature' => {
                'name' => {
                  key: PDF_INPUT_LOCATIONS.veteran[:signature][:name]
                },
                'date' => {
                  key: PDF_INPUT_LOCATIONS.veteran[:signature][:date],
                  format: 'date'
                }
              },
              'plannedClinic' => {
                key: PDF_INPUT_LOCATIONS.veteran[:planned_clinic]
              }
            },
            'primaryCaregiver' => {
              'address' => {
                'street' => {
                  key: PDF_INPUT_LOCATIONS.primaryCaregiver[:address][:street],
                  limit: 80,
                  question_num: 208,
                  question_text: 'PRIMARY FAMILY CAREGIVER > Address > Street'
                }
              },
              'mailingAddress' => {
                'street' => {
                  key: PDF_INPUT_LOCATIONS.primaryCaregiver[:mailingAddress][:street],
                  limit: 80,
                  question_num: 213,
                  question_text: 'PRIMARY FAMILY CAREGIVER > Mailing Address > Street'
                }
              },
              'gender' => {
                key: PDF_INPUT_LOCATIONS.primaryCaregiver[:gender]
              },
              'signature' => {
                'name' => {
                  key: PDF_INPUT_LOCATIONS.primaryCaregiver[:signature][:name]
                },
                'date' => {
                  key: PDF_INPUT_LOCATIONS.primaryCaregiver[:signature][:date],
                  format: 'date'
                }
              }
            },
            'secondaryCaregiverOne' => {
              'address' => {
                'street' => {
                  key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:address][:street],
                  limit: 80,
                  question_num: 308,
                  question_text: 'SECONDARY FAMILY CAREGIVER (1) > Address > Street'
                }
              },
              'mailingAddress' => {
                'street' => {
                  key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:mailingAddress][:street],
                  limit: 80,
                  question_num: 213,
                  question_text: 'SECONDARY FAMILY CAREGIVER (1) > Mailing Address > Street'
                }
              },
              'gender' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:gender]
              },
              'signature' => {
                'name' => {
                  key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:signature][:name]
                },
                'date' => {
                  key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:signature][:date],
                  format: 'date'
                }
              }
            },
            'secondaryCaregiverTwo' => {
              'address' => {
                'street' => {
                  key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:address][:street],
                  limit: 80,
                  question_num: 408,
                  question_text: 'SECONDARY FAMILY CAREGIVER (2) > Address > Street'
                }
              },
              'mailingAddress' => {
                'street' => {
                  key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:mailingAddress][:street],
                  limit: 80,
                  question_num: 413,
                  question_text: 'SECONDARY FAMILY CAREGIVER (2) > Mailing Address > Street'
                }
              },
              'gender' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:gender]
              },
              'signature' => {
                'name' => {
                  key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:signature][:name]
                },
                'date' => {
                  key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:signature][:date],
                  format: 'date'
                }
              }
            }
          },
          # Direct input
          'veteran' => {
            'fullName' => {
              'last' => {
                key: PDF_INPUT_LOCATIONS.veteran[:name][:last],
                limit: 29,
                question_num: 101,
                question_text: 'VETERAN/SERVICEMEMBER > Last Name'
              },
              'first' => {
                key: PDF_INPUT_LOCATIONS.veteran[:name][:first],
                limit: 29,
                question_num: 102,
                question_text: 'VETERAN/SERVICEMEMBER > First Name'
              },
              'middle' => {
                key: PDF_INPUT_LOCATIONS.veteran[:name][:middle],
                limit: 29,
                question_num: 103,
                question_text: 'VETERAN/SERVICEMEMBER > Middle Name'
              },
              'suffix' => {
                key: PDF_INPUT_LOCATIONS.veteran[:name][:suffix]
              }
            },
            'ssnOrTin' => {
              key: PDF_INPUT_LOCATIONS.veteran[:ssn]
            },
            'dateOfBirth' => {
              key: PDF_INPUT_LOCATIONS.veteran[:dob],
              format: 'date'
            },
            'address' => {
              'city' => {
                key: PDF_INPUT_LOCATIONS.veteran[:address][:city],
                limit: 29,
                question_num: 109,
                question_text: 'VETERAN/SERVICEMEMBER > Address > City'
              },
              'county' => {
                key: PDF_INPUT_LOCATIONS.veteran[:address][:county],
                limit: 29,
                question_num: 110,
                question_text: 'VETERAN/SERVICEMEMBER > Address > County'
              },
              'state' => {
                key: PDF_INPUT_LOCATIONS.veteran[:address][:state],
                limit: 29,
                question_num: 111,
                question_text: 'VETERAN/SERVICEMEMBER > Address > State'
              },
              'postalCode' => {
                key: PDF_INPUT_LOCATIONS.veteran[:address][:zip],
                limit: 29,
                question_num: 112,
                question_text: 'VETERAN/SERVICEMEMBER > Address > Zip Code'
              }
            },
            'primaryPhoneNumber' => {
              key: PDF_INPUT_LOCATIONS.veteran[:primary_phone]
            },
            'alternativePhoneNumber' => {
              key: PDF_INPUT_LOCATIONS.veteran[:alternative_phone]
            },
            'email' => {
              key: PDF_INPUT_LOCATIONS.veteran[:email],
              limit: 79,
              question_num: 115,
              question_text: 'VETERAN/SERVICEMEMBER > Email'
            }
          },
          'primaryCaregiver' => {
            'fullName' => {
              'last' => {
                key: PDF_INPUT_LOCATIONS.primaryCaregiver[:name][:last],
                limit: 29,
                question_num: 201,
                question_text: 'PRIMARY FAMILY CAREGIVER > Last Name'
              },
              'first' => {
                key: PDF_INPUT_LOCATIONS.primaryCaregiver[:name][:first],
                limit: 29,
                question_num: 202,
                question_text: 'PRIMARY FAMILY CAREGIVER > First Name'
              },
              'middle' => {
                key: PDF_INPUT_LOCATIONS.primaryCaregiver[:name][:middle],
                limit: 29,
                question_num: 203,
                question_text: 'PRIMARY FAMILY CAREGIVER > Middle Name'
              },
              'suffix' => {
                key: PDF_INPUT_LOCATIONS.primaryCaregiver[:name][:suffix]
              }
            },
            'ssnOrTin' => {
              key: PDF_INPUT_LOCATIONS.primaryCaregiver[:ssn]
            },
            'dateOfBirth' => {
              key: PDF_INPUT_LOCATIONS.primaryCaregiver[:dob],
              format: 'date'
            },
            'address' => {
              'city' => {
                key: PDF_INPUT_LOCATIONS.primaryCaregiver[:address][:city],
                limit: 29,
                question_num: 209,
                question_text: 'PRIMARY FAMILY CAREGIVER > Address > City'
              },
              'county' => {
                key: PDF_INPUT_LOCATIONS.primaryCaregiver[:address][:county],
                limit: 210,
                question_text: 'PRIMARY FAMILY CAREGIVER > Address > County'
              },
              'state' => {
                key: PDF_INPUT_LOCATIONS.primaryCaregiver[:address][:state],
                limit: 29,
                question_num: 211,
                question_text: 'PRIMARY FAMILY CAREGIVER > Address > State'
              },
              'postalCode' => {
                key: PDF_INPUT_LOCATIONS.primaryCaregiver[:address][:zip],
                limit: 29,
                question_num: 212,
                question_text: 'PRIMARY FAMILY CAREGIVER > Address > Zip Code'
              }
            },
            'mailingAddress' => {
              'city' => {
                key: PDF_INPUT_LOCATIONS.primaryCaregiver[:mailingAddress][:city],
                limit: 29,
                question_num: 214,
                question_text: 'PRIMARY FAMILY CAREGIVER > Mailing Address > City'
              },
              'county' => {
                key: PDF_INPUT_LOCATIONS.primaryCaregiver[:mailingAddress][:county],
                limit: 29,
                question_num: 215,
                question_text: 'PRIMARY FAMILY CAREGIVER > Mailing Address > County'
              },
              'state' => {
                key: PDF_INPUT_LOCATIONS.primaryCaregiver[:mailingAddress][:state],
                limit: 29,
                question_num: 216,
                question_text: 'PRIMARY FAMILY CAREGIVER > Mailing Address > State'
              },
              'postalCode' => {
                key: PDF_INPUT_LOCATIONS.primaryCaregiver[:mailingAddress][:zip],
                limit: 29,
                question_num: 217,
                question_text: 'PRIMARY FAMILY CAREGIVER > Mailing Address > Zip Code'
              }
            },
            'primaryPhoneNumber' => {
              key: PDF_INPUT_LOCATIONS.primaryCaregiver[:primary_phone]
            },
            'alternativePhoneNumber' => {
              key: PDF_INPUT_LOCATIONS.primaryCaregiver[:alternative_phone]
            },
            'email' => {
              key: PDF_INPUT_LOCATIONS.primaryCaregiver[:email],
              limit: 45,
              question_num: 220,
              question_text: 'PRIMARY FAMILY CAREGIVER > Email'
            },
            'vetRelationship' => {
              key: PDF_INPUT_LOCATIONS.primaryCaregiver[:vet_relationship]
            }
          },
          'secondaryCaregiverOne' => {
            'fullName' => {
              'last' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:name][:last],
                limit: 29,
                question_num: 301,
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > Last Name'
              },
              'first' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:name][:first],
                limit: 29,
                question_num: 302,
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > First Name'
              },
              'middle' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:name][:middle],
                limit: 29,
                question_num: 303,
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > Middle Name'
              },
              'suffix' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:name][:suffix],
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > Suffix'
              }
            },
            'ssnOrTin' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:ssn]
            },
            'dateOfBirth' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:dob],
              format: 'date'
            },
            'address' => {
              'city' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:address][:city],
                limit: 29,
                question_num: 309,
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > Address > City'
              },
              'county' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:address][:county],
                limit: 29,
                question_num: 310,
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > Address > County'
              },
              'state' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:address][:state],
                limit: 29,
                question_num: 311,
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > Address > State'
              },
              'postalCode' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:address][:zip],
                limit: 29,
                question_num: 312,
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > Address > Zip Code'
              }
            },
            'mailingAddress' => {
              'city' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:mailingAddress][:city],
                limit: 29,
                question_num: 314,
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > Mailing Address > City'
              },
              'county' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:mailingAddress][:county],
                limit: 29,
                question_num: 315,
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > Mailing Address > County'
              },
              'state' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:mailingAddress][:state],
                limit: 29,
                question_num: 316,
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > Mailing Address > State'
              },
              'postalCode' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:mailingAddress][:zip],
                limit: 29,
                question_num: 317,
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > Mailing Address > Zip Code'
              }
            },
            'primaryPhoneNumber' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:primary_phone]
            },
            'alternativePhoneNumber' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:alternative_phone]
            },
            'email' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:email],
              limit: 45,
              question_num: 320,
              question_text: 'SECONDARY FAMILY CAREGIVER (1) > Email'
            },
            'vetRelationship' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:vet_relationship]
            }
          },
          'secondaryCaregiverTwo' => {
            'fullName' => {
              'last' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:name][:last],
                limit: 29,
                question_num: 401,
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > Last Name'
              },
              'first' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:name][:first],
                limit: 29,
                question_num: 402,
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > First Name'
              },
              'middle' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:name][:middle],
                limit: 29,
                question_num: 403,
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > Middle Name'
              },
              'suffix' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:name][:suffix],
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > Suffix'
              }
            },
            'ssnOrTin' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:ssn]
            },
            'dateOfBirth' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:dob],
              format: 'date'
            },
            'address' => {
              'city' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:address][:city],
                limit: 29,
                question_num: 409,
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > Address > City'
              },
              'county' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:address][:county],
                limit: 29,
                question_num: 410,
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > Address > County'
              },
              'state' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:address][:state],
                limit: 29,
                question_num: 411,
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > Address > State'
              },
              'postalCode' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:address][:zip],
                limit: 29,
                question_num: 412,
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > Address > Zip'
              }
            },
            'mailingAddress' => {
              'city' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:mailingAddress][:city],
                limit: 29,
                question_num: 414,
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > Mailing Address > City'
              },
              'county' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:mailingAddress][:county],
                limit: 29,
                question_num: 415,
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > Mailing Address > County'
              },
              'state' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:mailingAddress][:state],
                limit: 29,
                question_num: 416,
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > Mailing Address > State'
              },
              'postalCode' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:mailingAddress][:zip],
                limit: 29,
                question_num: 417,
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > Mailing Address > Zip Code'
              }
            },
            'primaryPhoneNumber' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:primary_phone]
            },
            'alternativePhoneNumber' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:alternative_phone]
            },
            'email' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:email],
              limit: 45,
              question_num: 420,
              question_text: 'SECONDARY FAMILY CAREGIVER (2) > Email'
            },
            'vetRelationship' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:vet_relationship]
            }
          }
        }.freeze
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
