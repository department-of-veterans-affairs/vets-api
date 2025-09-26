# frozen_string_literal: true

require 'medical_expense_reports/pdf_fill/section'

module MedicalExpenseReports
  module PdfFill
    # Addendum C: Mileage For Privately Owned Vehicle Travel For Medical Expenses
    class AddendumC < Section
      # The Index Iterator Key
      ITERATOR = ::PdfFill::HashConverter::ITERATOR

      # Section configuration hash
      KEY = {
        'additionalMileage' => {
          limit: 8,
          first_key: 'travelTraveler',
          'travelTraveler' => {
            iterator_offset: ->(iterator) { iterator + 40 },
            key: "form1[0].#subform[14].RadioButtonList[#{ITERATOR}]"
          },
          'travelerName' => {
            question_num: 4,
            question_suffix: 'A',
            iterator_offset: ->(iterator) { iterator + 26 },
            key: "form1[0].#subform[14].Name_Of_Child_Or_Other[#{ITERATOR}]",
            question_label: 'Specify Name of Child or Other'
          },
          'travelLocation' => {
            key: "form1[0].#subform[14].Location_Traveled_To_Hospital_Clinic_Pharmacy_ETC[#{ITERATOR}]"
          },
          'travelMilesTraveled' => {
            iterator_offset: ->(iterator) { iterator + 4 },
            key: "form1[0].#subform[14].Total_Miles_Traveled[#{ITERATOR}]"
          },
          'travelReimbursementAmount' => {
            'thousands' => {
              key: "form1[0].#subform[14].Amount_Reimbursed_From_Any_Source_VA_Medical_Center_ETC[#{ITERATOR}]"
            },
            'dollars' => {
              iterator_offset: ->(iterator) { iterator * 2 + 38 },
              key: "form1[0].#subform[14].Amount[#{ITERATOR}]"
            },
            'cents' => {
              iterator_offset: ->(iterator) { iterator * 2 + 39 },
              key: "form1[0].#subform[14].Amount[#{ITERATOR}]"
            }
          },
          'travelDate' => {
            'month' => {
              iterator_offset: ->(iterator) { iterator + 4 },
              key: "form1[0].#subform[14].Date_Traveled_Month[#{ITERATOR}]"
            },
            'day' => {
              key: "form1[0].#subform[14].Date_Day[#{ITERATOR}]"
            },
            'year' => {
              key: "form1[0].#subform[14].Date_Year[#{ITERATOR}]"
            }
          }
        }
      }.freeze

      def expand(form_data = {})
        form_data['additionalMileage'] ||= []
        form_data['additionalMileage'] = form_data['mileage'].drop(4).map { |t| expand_traveler(t) }
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
