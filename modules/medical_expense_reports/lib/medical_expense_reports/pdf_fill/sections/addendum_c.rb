# frozen_string_literal: true

require 'medical_expense_reports/pdf_fill/section'

require_relative '../../constants'

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
              iterator_offset: ->(iterator) { (iterator * 2) + 38 },
              key: "form1[0].#subform[14].Amount[#{ITERATOR}]"
            },
            'cents' => {
              iterator_offset: ->(iterator) { (iterator * 2) + 39 },
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

      # espand mileage expenses
      def expand(form_data = {})
        form_data['mileageExpenses'] ||= []
        form_data['additionalMileage'] = form_data['mileageExpenses'].drop(4).map { |t| expand_traveler(t) }
        form_data
      end

      # expand traveler
      def expand_traveler(traveler)
        traveler['travelReimbursementAmount'] =
          split_currency_amount_sm(traveler['travelReimbursementAmount'], { 'thousands' => 3 })
        traveler['travelDate'] = split_date(traveler['travelDate'])
        traveler['travelTraveler'] = Constants::RECIPIENTS[traveler['traveler']] || 'Off'
        traveler
      end
    end
  end
end
