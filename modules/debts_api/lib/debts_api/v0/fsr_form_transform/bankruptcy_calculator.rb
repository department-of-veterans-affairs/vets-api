# frozen_string_literal: true

require 'date'

module DebtsApi
  module V0
    module FsrFormTransform
      class BankruptcyCalculator
        def initialize(form)
          @form = form
        end

        def get_bankruptcy_data
          {
            'hasBeenAdjudicatedBankrupt' => @form.dig('questions', 'has_been_adjudicated_bankrupt'),
            'dateDischarged' => get_discharged_date,
            'courtLocation' => @form.dig('additional_data', 'bankruptcy', 'court_location'),
            'docketNumber' => @form.dig('additional_data', 'bankruptcy', 'docket_number')
          }
        end

        private

        def get_discharged_date
          raw_date = @form.dig('additional_data', 'bankruptcy', 'date_discharged')
          date_object = Date.parse(raw_date)

          "#{date_object.strftime('%m')}/#{date_object.year}"
        end
      end
    end
  end
end
