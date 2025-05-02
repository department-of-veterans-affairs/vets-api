# frozen_string_literal: true

module PdfFill
  module Forms
    module FieldMappings
      # rubocop:disable Metrics/ClassLength
      class Va1010cg
        KEY = {
          'helpers' => {
            'veteran' => {
              'address' => {
                'street' => {
                  key: 'form1[0].#subform[15].StreetAddress[0]',
                  limit: 80,
                  question_num: 108,
                  question_text: 'VETERAN/SERVICEMEMBER > Address > Street'
                }
              },
              'gender' => {
                key: 'form1[0].#subform[15].RadioButtonList[0]'
              },
              'signature' => {
                'name' => {
                  key: 'form1[0].#subform[15].Signature[0]'
                },
                'date' => {
                  key: 'form1[0].#subform[15].DateSigned[0]',
                  format: 'date'
                }
              },
              'plannedClinic' => {
                key: 'form1[0].#subform[15].NameVAMedicalCenter[0]'
              }
            },
            'primaryCaregiver' => {
              'address' => {
                'street' => {
                  key: 'form1[0].#subform[16].StreetAddress[1]',
                  limit: 80,
                  question_num: 208,
                  question_text: 'PRIMARY FAMILY CAREGIVER > Address > Street'
                }
              },
              'mailingAddress' => {
                'street' => {
                  key: 'form1[0].#subform[16].MailingStreetAddress[0]',
                  limit: 80,
                  question_num: 213,
                  question_text: 'PRIMARY FAMILY CAREGIVER > Mailing Address > Street'
                }
              },
              'gender' => {
                key: 'form1[0].#subform[16].RadioButtonList[1]'
              },
              'signature' => {
                'name' => {
                  key: 'form1[0].#subform[16].Signature[1]'
                },
                'date' => {
                  key: 'form1[0].#subform[16].DateSigned[1]',
                  format: 'date'
                }
              }
            },
            'secondaryCaregiverOne' => {
              'address' => {
                'street' => {
                  key: 'form1[0].#subform[17].StreetAddress[2]',
                  limit: 80,
                  question_num: 308,
                  question_text: 'SECONDARY FAMILY CAREGIVER (1) > Address > Street'
                }
              },
              'mailingAddress' => {
                'street' => {
                  key: 'form1[0].#subform[17].MailingStreetAddress[1]',
                  limit: 80,
                  question_num: 213,
                  question_text: 'SECONDARY FAMILY CAREGIVER (1) > Mailing Address > Street'
                }
              },
              'gender' => {
                key: 'form1[0].#subform[17].RadioButtonList[2]'
              },
              'signature' => {
                'name' => {
                  key: 'form1[0].#subform[17].Signature[2]'
                },
                'date' => {
                  key: 'form1[0].#subform[17].DateSigned[2]',
                  format: 'date'
                }
              }
            },
            'secondaryCaregiverTwo' => {
              'address' => {
                'street' => {
                  key: 'form1[0].#subform[18].StreetAddress[3]',
                  limit: 80,
                  question_num: 408,
                  question_text: 'SECONDARY FAMILY CAREGIVER (2) > Address > Street'
                }
              },
              'mailingAddress' => {
                'street' => {
                  key: 'form1[0].#subform[18].MailingStreetAddress[2]',
                  limit: 80,
                  question_num: 413,
                  question_text: 'SECONDARY FAMILY CAREGIVER (2) > Mailing Address > Street'
                }
              },
              'gender' => {
                key: 'form1[0].#subform[18].RadioButtonList[3]'
              },
              'signature' => {
                'name' => {
                  key: 'form1[0].#subform[18].Signature[3]'
                },
                'date' => {
                  key: 'form1[0].#subform[18].DateSigned[3]',
                  format: 'date'
                }
              }
            }
          },
          'veteran' => {
            'fullName' => {
              'last' => {
                key: 'form1[0].#subform[15].LastName[0]',
                limit: 29,
                question_num: 101,
                question_text: 'VETERAN/SERVICEMEMBER > Last Name'
              },
              'first' => {
                key: 'form1[0].#subform[15].FirstName[0]',
                limit: 29,
                question_num: 102,
                question_text: 'VETERAN/SERVICEMEMBER > First Name'
              },
              'middle' => {
                key: 'form1[0].#subform[15].MiddleName[0]',
                limit: 29,
                question_num: 103,
                question_text: 'VETERAN/SERVICEMEMBER > Middle Name'
              },
              'suffix' => {
                key: 'form1[0].#subform[15].Suffix[0]'
              }
            },
            'ssnOrTin' => {
              key: 'form1[0].#subform[15].SSN_TaxID[0]'
            },
            'dateOfBirth' => {
              key: 'form1[0].#subform[15].DateOfBirth[0]',
              format: 'date'
            },
            'address' => {
              'city' => {
                key: 'form1[0].#subform[15].City[0]',
                limit: 29,
                question_num: 109,
                question_text: 'VETERAN/SERVICEMEMBER > Address > City'
              },
              'county' => {
                key: 'form1[0].#subform[15].County[0]',
                limit: 29,
                question_num: 110,
                question_text: 'VETERAN/SERVICEMEMBER > Address > County'
              },
              'state' => {
                key: 'form1[0].#subform[15].State[0]',
                limit: 29,
                question_num: 111,
                question_text: 'VETERAN/SERVICEMEMBER > Address > State'
              },
              'postalCode' => {
                key: 'form1[0].#subform[15].Zip[0]',
                limit: 29,
                question_num: 112,
                question_text: 'VETERAN/SERVICEMEMBER > Address > Zip Code'
              }
            },
            'primaryPhoneNumber' => {
              key: 'form1[0].#subform[15].PrimaryPhone[0]'
            },
            'alternativePhoneNumber' => {
              key: 'form1[0].#subform[15].AltPhone[0]'
            },
            'email' => {
              key: 'form1[0].#subform[15].Email[0]',
              limit: 79,
              question_num: 115,
              question_text: 'VETERAN/SERVICEMEMBER > Email'
            }
          },
          'primaryCaregiver' => {
            'fullName' => {
              'last' => {
                key: 'form1[0].#subform[16].LastName[1]',
                limit: 29,
                question_num: 201,
                question_text: 'PRIMARY FAMILY CAREGIVER > Last Name'
              },
              'first' => {
                key: 'form1[0].#subform[16].FirstName[1]',
                limit: 29,
                question_num: 202,
                question_text: 'PRIMARY FAMILY CAREGIVER > First Name'
              },
              'middle' => {
                key: 'form1[0].#subform[16].MiddleName[1]',
                limit: 29,
                question_num: 203,
                question_text: 'PRIMARY FAMILY CAREGIVER > Middle Name'
              },
              'suffix' => {
                key: 'form1[0].#subform[16].Suffix[1]'
              }
            },
            'ssnOrTin' => {
              key: 'form1[0].#subform[16].SSN_TaxID[1]'
            },
            'dateOfBirth' => {
              key: 'form1[0].#subform[16].DateOfBirth[1]',
              format: 'date'
            },
            'address' => {
              'city' => {
                key: 'form1[0].#subform[16].City[1]',
                limit: 29,
                question_num: 209,
                question_text: 'PRIMARY FAMILY CAREGIVER > Address > City'
              },
              'county' => {
                key: 'form1[0].#subform[16].County[1]',
                limit: 210,
                question_text: 'PRIMARY FAMILY CAREGIVER > Address > County'
              },
              'state' => {
                key: 'form1[0].#subform[16].State[1]',
                limit: 29,
                question_num: 211,
                question_text: 'PRIMARY FAMILY CAREGIVER > Address > State'
              },
              'postalCode' => {
                key: 'form1[0].#subform[16].Zip[1]',
                limit: 29,
                question_num: 212,
                question_text: 'PRIMARY FAMILY CAREGIVER > Address > Zip Code'
              }
            },
            'mailingAddress' => {
              'city' => {
                key: 'form1[0].#subform[16].City[2]',
                limit: 29,
                question_num: 214,
                question_text: 'PRIMARY FAMILY CAREGIVER > Mailing Address > City'
              },
              'county' => {
                key: 'form1[0].#subform[16].County[2]',
                limit: 29,
                question_num: 215,
                question_text: 'PRIMARY FAMILY CAREGIVER > Mailing Address > County'
              },
              'state' => {
                key: 'form1[0].#subform[16].State[2]',
                limit: 29,
                question_num: 216,
                question_text: 'PRIMARY FAMILY CAREGIVER > Mailing Address > State'
              },
              'postalCode' => {
                key: 'form1[0].#subform[16].Zip[2]',
                limit: 29,
                question_num: 217,
                question_text: 'PRIMARY FAMILY CAREGIVER > Mailing Address > Zip Code'
              }
            },
            'primaryPhoneNumber' => {
              key: 'form1[0].#subform[16].PrimaryPhone[1]'
            },
            'alternativePhoneNumber' => {
              key: 'form1[0].#subform[16].AltPhone[1]'
            },
            'email' => {
              key: 'form1[0].#subform[16].Email[1]',
              limit: 45,
              question_num: 220,
              question_text: 'PRIMARY FAMILY CAREGIVER > Email'
            },
            'vetRelationship' => {
              key: 'form1[0].#subform[16].Relationship[0]'
            }
          },
          'secondaryCaregiverOne' => {
            'fullName' => {
              'last' => {
                key: 'form1[0].#subform[17].LastName[2]',
                limit: 29,
                question_num: 301,
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > Last Name'
              },
              'first' => {
                key: 'form1[0].#subform[17].FirstName[2]',
                limit: 29,
                question_num: 302,
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > First Name'
              },
              'middle' => {
                key: 'form1[0].#subform[17].MiddleName[2]',
                limit: 29,
                question_num: 303,
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > Middle Name'
              },
              'suffix' => {
                key: 'form1[0].#subform[17].Suffix[2]',
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > Suffix'
              }
            },
            'ssnOrTin' => {
              key: 'form1[0].#subform[17].SSN_TaxID[2]'
            },
            'dateOfBirth' => {
              key: 'form1[0].#subform[17].DateOfBirth[2]',
              format: 'date'
            },
            'address' => {
              'city' => {
                key: 'form1[0].#subform[17].City[3]',
                limit: 29,
                question_num: 309,
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > Address > City'
              },
              'county' => {
                key: 'form1[0].#subform[17].County[3]',
                limit: 29,
                question_num: 310,
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > Address > County'
              },
              'state' => {
                key: 'form1[0].#subform[17].State[3]',
                limit: 29,
                question_num: 311,
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > Address > State'
              },
              'postalCode' => {
                key: 'form1[0].#subform[17].Zip[3]',
                limit: 29,
                question_num: 312,
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > Address > Zip Code'
              }
            },
            'mailingAddress' => {
              'city' => {
                key: 'form1[0].#subform[17].City[4]',
                limit: 29,
                question_num: 314,
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > Mailing Address > City'
              },
              'county' => {
                key: 'form1[0].#subform[17].County[4]',
                limit: 29,
                question_num: 315,
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > Mailing Address > County'
              },
              'state' => {
                key: 'form1[0].#subform[17].State[4]',
                limit: 29,
                question_num: 316,
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > Mailing Address > State'
              },
              'postalCode' => {
                key: 'form1[0].#subform[17].Zip[4]',
                limit: 29,
                question_num: 317,
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > Mailing Address > Zip Code'
              }
            },
            'primaryPhoneNumber' => {
              key: 'form1[0].#subform[17].PrimaryPhone[2]'
            },
            'alternativePhoneNumber' => {
              key: 'form1[0].#subform[17].AltPhone[2]'
            },
            'email' => {
              key: 'form1[0].#subform[17].Email[2]',
              limit: 45,
              question_num: 320,
              question_text: 'SECONDARY FAMILY CAREGIVER (1) > Email'
            },
            'vetRelationship' => {
              key: 'form1[0].#subform[17].Relationship[1]'
            }
          },
          'secondaryCaregiverTwo' => {
            'fullName' => {
              'last' => {
                key: 'form1[0].#subform[18].LastName[3]',
                limit: 29,
                question_num: 401,
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > Last Name'
              },
              'first' => {
                key: 'form1[0].#subform[18].FirstName[3]',
                limit: 29,
                question_num: 402,
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > First Name'
              },
              'middle' => {
                key: 'form1[0].#subform[18].MiddleName[3]',
                limit: 29,
                question_num: 403,
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > Middle Name'
              },
              'suffix' => {
                key: 'form1[0].#subform[18].Suffix[3]',
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > Suffix'
              }
            },
            'ssnOrTin' => {
              key: 'form1[0].#subform[18].SSN_TaxID[3]'
            },
            'dateOfBirth' => {
              key: 'form1[0].#subform[18].DateOfBirth[3]',
              format: 'date'
            },
            'address' => {
              'city' => {
                key: 'form1[0].#subform[18].City[5]',
                limit: 29,
                question_num: 409,
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > Address > City'
              },
              'county' => {
                key: 'form1[0].#subform[18].County[5]',
                limit: 29,
                question_num: 410,
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > Address > County'
              },
              'state' => {
                key: 'form1[0].#subform[18].State[5]',
                limit: 29,
                question_num: 411,
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > Address > State'
              },
              'postalCode' => {
                key: 'form1[0].#subform[18].Zip[5]',
                limit: 29,
                question_num: 412,
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > Address > Zip'
              }
            },
            'mailingAddress' => {
              'city' => {
                key: 'form1[0].#subform[18].City[6]',
                limit: 29,
                question_num: 414,
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > Mailing Address > City'
              },
              'county' => {
                key: 'form1[0].#subform[18].County[6]',
                limit: 29,
                question_num: 415,
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > Mailing Address > County'
              },
              'state' => {
                key: 'form1[0].#subform[18].State[6]',
                limit: 29,
                question_num: 416,
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > Mailing Address > State'
              },
              'postalCode' => {
                key: 'form1[0].#subform[18].Zip[6]',
                limit: 29,
                question_num: 417,
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > Mailing Address > Zip Code'
              }
            },
            'primaryPhoneNumber' => {
              key: 'form1[0].#subform[18].PrimaryPhone[3]'
            },
            'alternativePhoneNumber' => {
              key: 'form1[0].#subform[18].AltPhone[3]'
            },
            'email' => {
              key: 'form1[0].#subform[18].Email[3]',
              limit: 45,
              question_num: 420,
              question_text: 'SECONDARY FAMILY CAREGIVER (2) > Email'
            },
            'vetRelationship' => {
              key: 'form1[0].#subform[18].Relationship[2]'
            }
          }
        }.freeze
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
