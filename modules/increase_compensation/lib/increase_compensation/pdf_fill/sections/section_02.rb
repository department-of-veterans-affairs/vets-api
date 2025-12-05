# frozen_string_literal: true

require 'increase_compensation/pdf_fill/section'

module IncreaseCompensation
  module PdfFill
    # Section II: Disability and Medical Treatment
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
          question_label: 'Dates of Doctors Treaments',
          question_text: 'Dates of Doctors Treaments',
          'from' => {
            'month' => {
              limit: 2,
              key: 'form1[0].#subform[0].Month[1]'
            },
            'day' => {
              limit: 2,
              key: 'form1[0].#subform[0].Day[1]'
            },
            'year' => {
              limit: 4,
              question_num: 10,
              question_text: 'Doctors Treatment Dates Continued',
              question_label: 'Doctors Treatment Dates Continued',
              key: 'form1[0].#subform[0].Year[3]'
            }
          },
          'to' => {
            'month' => {
              limit: 2,
              key: 'form1[0].#subform[0].Month[2]'
            },
            'day' => {
              limit: 2,
              key: 'form1[0].#subform[0].Day[2]'
            },
            'year' => {
              limit: 4,
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
        'doctorsCareOverflow' => {
          key: '',
          question_num: 11,
          question_label: 'Doctors Care Continued',
          question_text: 'Doctors Care Continued',
          always_overflow: true
        },
        'nameAndAddressesOfHospitals' => {
          question_num: 12,
          limit: 127,
          question_label: 'Name and Addresses of Hospitals',
          question_text: 'Name and Addresses of Hospitals',
          key: 'form1[0].#subform[0].Name_And_Address_Of_Hospital[0]'
        },
        'hospitalTreatmentDates' => {
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
              question_num: 13,
              question_text: 'Hospitalization Dates Continued',
              question_label: 'Hospitalization Dates Continued',
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
        },
        'hospitalCareOverflow' => {
          key: '',
          question_num: 12,
          question_label: 'Hospital Care Continued',
          question_text: 'Hospital Care Continued',
          always_overflow: true
        }
      }.freeze

      def expand(form_data = {})
        form_data['doctorsCareInLastYTD'] = resolve_boolean_checkbox(form_data['doctorsCareInLastYTD'])

        %w[doctorsCare hospitalsCare].each do |care_type|
          items = form_data[care_type]
          next if items.blank?

          # set up our keys
          is_docotor = care_type == 'doctorsCare'
          treatment_dates_key =  is_docotor ? 'doctorsTreatmentDates' : 'hospitalTreatmentDates'
          name_and_address_key = is_docotor ? 'nameAndAddressesOfDoctors' : 'nameAndAddressesOfHospitals'
          overflow_key = is_docotor ? 'doctorsCareOverflow' : 'hospitalCareOverflow'

          if items.length == 1
            form_data[treatment_dates_key], form_data[name_and_address_key] =
              format_first_care_item(items.first)
          else
            form_data[overflow_key] = [
              overflow_doc_and_hospitals(items, is_docotor).join("\n\n")
            ]
            form_data[name_and_address_key] = 'See Additional Pages'
          end
        end
      end
    end
  end
end
