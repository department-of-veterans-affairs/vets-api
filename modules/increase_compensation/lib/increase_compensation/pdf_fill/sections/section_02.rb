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
          limit: 81,
          key: 'form1[0].#subform[0].Service_Connected_Disability[0]'
        },
        'doctorsCareInLastYTD' => {
          question_num: 9,
          key: 'form1[0].#subform[0].RadioButtonList[0]'
        },
        'doctorsTreatmentDates' => {
          question_num: 10,
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
          limit: 135,
          key: 'form1[0].#subform[0].Name_And_Address_Of_Doctors[0]'
        },
        'nameAndAddressesOfHospitals' => {
          question_num: 12,
          limit: 127,
          key: 'form1[0].#subform[0].Name_And_Address_Of_Hospital[0]'
        },
        'hospitalCareDateRanges' => {
          question_num: 13,
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
        # dates
        form_data['doctorsTreatmentDates'] = {
          'from' => split_date(form_data['doctorsTreatmentDates']['from']),
          'to' => split_date(form_data['doctorsTreatmentDates']['to'])
        }
        form_data['hospitalCareDateRanges'] = {
          'from' => split_date(form_data['hospitalCareDateRanges']['from']),
          'to' => split_date(form_data['hospitalCareDateRanges']['to'])
        }
      end
    end
  end
end
