# frozen_string_literal: true

require 'increase_compensation/pdf_fill/section'

module IncreaseCompensation
  module PdfFill
    # Section II: Disablitiy and Medical Treatment
    class Section2 < Section
      # Section configuration hash
      KEY = {
        'listOfDisabilities' => {
          question_num: 8,
          question_label: 'List of Disabilities',
          question_text: 'List of Disabilities',
          limit: 81,
          key: 'form1[0].#subform[0].Service_Connected_Disability[0]'
        },
        'doctorsCareInLastYTD' => {
          question_num: 9,
          key: 'form1[0].#subform[0].RadioButtonList[0]'
        },
        'doctorsTreatmentDates' => {
          question_num: 10,
          question_label: 'Dats of Doctors Treaments',
          question_text: 'Dats of Doctors Treaments',
          'from' => {
            'month' => {
              key: 'form1[0].#subform[0].Month[1]'
            },
            'day' => {
              key: 'form1[0].#subform[0].Day[1]'
            },
            'year' => {
              key: 'form1[0].#subform[0].Year[3]'
            }
          },
          'to' => {
            'month' => {
              key: 'form1[0].#subform[0].Month[2]'
            },
            'day' => {
              key: 'form1[0].#subform[0].Day[2]'
            },
            'year' => {
              key: 'form1[0].#subform[0].Year[4]'
            }
          }
        },
        'nameAndAddressesOfDoctors' => {
          question_num: 11,
          question_label: 'Name and Addresses of Doctors',
          question_text: 'Name and Addresses of Doctors',
          limit: 135,
          key: 'form1[0].#subform[0].Name_And_Address_Of_Doctors[0]'
        },
        'nameAndAddressesOfHospitals' => {
          question_num: 12,
          limit: 127,
          question_label: 'Name and Addresses of Hospitals',
          question_text: 'Name and Addresses of Hospitals',
          key: 'form1[0].#subform[0].Name_And_Address_Of_Hospital[0]'
        },
        'hospitalCareDateRanges' => {
          question_num: 13,
          question_label: 'Hospitail Care Date Ranges',
          question_text: 'Hospitail Care Date Ranges',
          'from' => {
            'month' => {
              limit: 2,
              key: 'form1[0].#subform[0].Month[3]'
            },
            'day' => {
              limit: 2,
              key: 'form1[0].#subform[0].Day[3]'
            },
            'year' => {
              limit: 4,
              key: 'form1[0].#subform[0].Year[6]'
            }
          },
          'to' => {
            'month' => {
              limit: 2,
              key: 'form1[0].#subform[0].Month[4]'
            },
            'day' => {
              limit: 2,
              key: 'form1[0].#subform[0].Day[4]'
            },
            'year' => {
              limit: 4,
              key: 'form1[0].#subform[0].Year[8]'
            }
          }
        }
      }.freeze

      def expand(form_data = {})
        form_data['doctorsCareInLastYTD'] = case form_data['doctorsCareInLastYTD']
                                            when true
                                              'YES'
                                            when false
                                              'NO'
                                            else
                                              'OFF'
                                            end

        form_data['doctorsTreatmentDates'] = map_date_range(form_data['doctorsTreatmentDates'])
        form_data['hospitalCareDateRanges'] = map_date_range(form_data['hospitalCareDateRanges'])
      end
    end
  end
end
