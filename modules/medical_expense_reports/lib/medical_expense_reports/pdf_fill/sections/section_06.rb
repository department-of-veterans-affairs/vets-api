# frozen_string_literal: true

require 'medical_expense_reports/pdf_fill/section'

module MedicalExpenseReports
  module PdfFill
    # Section VI: Mileage
    class Section6 < Section

      # The Index Iterator Key
      ITERATOR = ::PdfFill::HashConverter::ITERATOR

      # Section configuration hash
      KEY = {
        'primaryMileage' => {
          limit: 4,
          first_key: 'travelTraveler',
          'travelTraveler' => {
            iterator_offset: ->(iterator) { iterator + 16 },
            key: "form1[0].#subform[11].RadioButtonList[#{ITERATOR}]"
          },
          'travelerName' => {
            question_num: 4,
            question_suffix: 'A',
            iterator_offset: ->(iterator) { iterator + 9 },
            key: "form1[0].#subform[11].Name_Of_Child_Or_Other[#{ITERATOR}]",
            question_label: 'Specify Name of Child or Other'
          },
          'travelLocation' => {
            key: "form1[0].#subform[11].Provide_Location_Traveled_To_Hospital_Clinic_Pharmacy_ETC[#{ITERATOR}]"
          },
          'travelMilesTraveled' => {
            key: "form1[0].#subform[11].Total_Miles_Traveled[#{ITERATOR}]"
          },
          'travelReimbursementAmount' => {
            'thousands' => {
              iterator_offset: ->(iterator) { iterator * 3 + 1 },
              key: "form1[0].#subform[11].Amount[#{ITERATOR}]"
            },
            'dollars' => {
              iterator_offset: ->(iterator) { iterator * 3 },
              key: "form1[0].#subform[11].Amount[#{ITERATOR}]"
            },
            'cents' => {
              iterator_offset: ->(iterator) { iterator * 3 + 2 },
              key: "form1[0].#subform[11].Amount[#{ITERATOR}]"
            }
          },
          'travelDate' => {
            'month' => {
              key: "form1[0].#subform[11].Date_Traveled_Month[#{ITERATOR}]"
            },
            'day' => {
              key: "form1[0].#subform[11].Date_Traveled_Day[#{ITERATOR}]"
            },
            'year' => {
              key: "form1[0].#subform[11].Date_Traveled_Year[#{ITERATOR}]"
            }
          }
        }
      }.freeze

      def expand(form_data = {})
        form_data['primaryMileage'] ||= []
        form_data['primaryMileage'] = form_data['mileage'].take(4).map { |t| expand_traveler(t) } # the rest go on Addendum C
        form_data
      end

      def expand_traveler(traveler)
        traveler['travelReimbursementAmount'] = split_currency_amount_sm(traveler['travelReimbursementAmount'], { 'thousands' => 3 })
        traveler['travelDate'] = split_date(traveler['travelDate'])
        traveler['travelTraveler'] = traveler_to_radio(traveler['traveler'])
        traveler
      end

      def traveler_to_radio(traveler)
        case traveler
        when 'VETERAN' then 4
        when 'SPOUSE' then 1
        when 'CHILD' then 3
        when 'OTHER' then 2
        else 'Off'
        end
      end
    end
  end
end
