# frozen_string_literal: true

module DebtsApi
  module V0
    module FsrFormTransform
      class PersonalIdentificationCalculator
        def initialize(form)
          @form = form['personal_identification']
          @selected_debts_and_copays = form['selected_debts_and_copays']
        end

        def transform_personal_id
          {
            'ssn' => @form['ssn'],
            'fileNumber' => @form['file_number'],
            'fsrReason' => get_resolution_options
          }
        end

        private

        def get_resolution_options
          @selected_debts_and_copays.map do |debt_copay|
            resolution_options_map[debt_copay['resolution_option']]
          end.uniq.join(', ')
        end

        def resolution_options_map
          { 'waiver' => 'Waiver',
            'monthly' => 'Extended monthly payments',
            'compromise' => 'Compromise' }
        end
      end
    end
  end
end
