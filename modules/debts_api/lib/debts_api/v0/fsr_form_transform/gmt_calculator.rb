# frozen_string_literal: true

require 'debts_api/v0/fsr_form_transform/utils'

module DebtsApi
  module V0
    module FsrFormTransform
      class GmtCalculator
        include ::FsrFormTransform::Utils
        class InvalidYear < StandardError; end
        class InvalidDependentCount < StandardError; end
        class InvalidZipCode < StandardError; end

        INCOME_UPPER_PERCENTAGE = 1.5
        ASSET_PERCENTAGE = 0.065
        DISCRETIONARY_INCOME_PERCENTAGE = 0.0125

        attr_reader :year, :dependents, :zipcode,
                    :income_threshold_data, :gmt_threshold_data,
                    :pension_threshold, :national_threshold, :gmt_threshold

        def initialize(year:, dependents:, zipcode:)
          @year = year.to_i
          @dependents = dependents.to_i
          @zipcode_data = find_zipcode_data(zipcode)
          validate_inputs
          @income_threshold_year = @year - 1
          @income_threshold_data = find_income_threshold_data(@income_threshold_year)
          @gmt_threshold_data = find_gmt_threshold_data

          @pension_threshold = calculate_pension_threshold
          @national_threshold = calculate_national_threshold
          @gmt_threshold = calculate_gmt_threshold
        end

        def income_limits
          {
            pension_threshold: @pension_threshold,
            national_threshold: @national_threshold,
            gmt_threshold: @gmt_threshold,
            income_upper_threshold: @gmt_threshold * INCOME_UPPER_PERCENTAGE,
            asset_threshold: @gmt_threshold * ASSET_PERCENTAGE,
            discretionary_income_threshold: @gmt_threshold * DISCRETIONARY_INCOME_PERCENTAGE
          }
        end

        private

        def calculate_gmt_threshold
          return {} if gmt_threshold_data.nil?

          if dependents <= 7
            gmt_value = gmt_threshold_data.send("trhd#{dependents + 1}")
          else
            delta = gmt_threshold_data.trhd8 - gmt_threshold_data.trhd7
            gmt_value = gmt_threshold_data.trhd8 + (delta * (dependents - 7))
          end

          gmt_value
        end

        def calculate_national_threshold
          return {} if income_threshold_data.nil?

          exempt_amount = income_threshold_data.exempt_amount
          dependent = income_threshold_data.dependent
          add_dependent_threshold = income_threshold_data.add_dependent_threshold
          if dependents.zero?
            exempt_amount
          elsif dependents == 1
            dependent
          else
            additional_dependents = (dependents - 1) * add_dependent_threshold
            dependent + additional_dependents
          end
        end

        def calculate_pension_threshold
          return {} if income_threshold_data.nil?

          pension_threshold = income_threshold_data.pension_threshold
          pension_1_dependent = income_threshold_data.pension_1_dependent
          add_dependent_pension = income_threshold_data.add_dependent_pension
          if dependents.zero?
            pension_threshold
          elsif dependents == 1
            pension_1_dependent
          else
            additional_dependents = (dependents - 1) * add_dependent_pension
            pension_1_dependent + additional_dependents
          end
        end

        def find_income_threshold_data(year)
          StdIncomeThreshold.find_by(income_threshold_year: year)
        end

        def find_county_data(zipcode_data)
          StdCounty.where(county_number: zipcode_data.county_number, state_id: zipcode_data.state_id).first
        end

        def find_gmt_threshold_data
          state_data = StdState.find_by(id: @zipcode_data.state_id)
          county_data = find_county_data(@zipcode_data)
          state_fips_code = state_data.fips_code
          county_number = format('%03d', county_data.county_number)
          county_indentifier = state_fips_code.to_s + county_number.to_s
          GmtThreshold.where(fips: county_indentifier)
                      .where(effective_year: @income_threshold_year)
                      .order(trhd1: :desc)
                      .first
        end

        def valid_year?
          @year.between?(2001, 2999)
        end

        def valid_dependents?
          @dependents.between?(0, 100)
        end

        def validate_inputs
          raise InvalidYear unless valid_year?
          raise InvalidDependentCount unless valid_dependents?
          raise InvalidZipCode unless @zipcode_data
        end
      end
    end
  end
end
