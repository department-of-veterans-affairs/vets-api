# frozen_string_literal: true

module IncomeLimits
  module V1
    class IncomeLimitsController < ApplicationController
      skip_before_action :authenticate

      def index
        zip = sanitized_zip_param
        benefit_year = params[:year].to_i
        dependents = params[:dependents].to_i
        return render_invalid_year_error unless valid_year?(benefit_year)
        return render_invalid_dependents_error unless valid_dependents?(dependents)

        income_threshold_year = benefit_year - 1
        income_threshold_data = find_income_threshold_data(income_threshold_year)
        zipcode_data = find_zipcode_data(zip)
        return render_zipcode_not_found_error unless zipcode_data

        gmt_threshold_data = find_gmt_threshold_data(zipcode_data, income_threshold_year)

        response = {
          pension_threshold: calculate_pension_threshold(income_threshold_data, dependents),
          national_threshold: calculate_national_threshold(income_threshold_data, dependents),
          gmt_threshold: calculate_gmt_threshold(gmt_threshold_data, dependents)
        }

        render json: { data: response }
      end

      def validate_zip_code
        zip = sanitized_zip_param
        zipcode_data = find_zipcode_data(zip)
        response = zipcode_data&.county_number ? true : false
        render json: { zip_is_valid: response }
      end

      private

      def valid_year?(year)
        year.between?(2015, 2999)
      end

      def valid_dependents?(dependents)
        dependents.between?(0, 100)
      end

      def calculate_pension_threshold(income_threshold_data, dependents)
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

      def calculate_national_threshold(income_threshold_data, dependents)
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

      def calculate_gmt_threshold(gmt_threshold_data, dependents)
        return {} if gmt_threshold_data.nil?

        if dependents <= 7
          gmt_value = gmt_threshold_data.send("trhd#{dependents + 1}")
        else
          delta = gmt_threshold_data.trhd8 - gmt_threshold_data.trhd7
          gmt_value = gmt_threshold_data.trhd8 + (delta * (dependents - 7))
        end

        gmt_value
      end

      def sanitized_zip_param
        params[:zip].to_s
      end

      def find_zipcode_data(zip)
        StdZipcode.find_by(zip_code: zip)
      end

      def find_income_threshold_data(year)
        StdIncomeThreshold.find_by(income_threshold_year: year)
      end

      def find_county_data(zipcode_data)
        StdCounty.where(county_number: zipcode_data.county_number, state_id: zipcode_data.state_id).first
      end

      # rubocop:disable Layout/LineLength
      def find_gmt_threshold_data(zipcode_data, year)
        state_data = StdState.find_by(id: zipcode_data.state_id)
        county_data = find_county_data(zipcode_data)
        state_name = state_data.name
        county_name = county_data.name

        GmtThreshold
          .where('lower(state_name) = ? AND lower(county_name) = ?', state_name.downcase, "#{county_name.downcase} county")
          .where(effective_year: year)
          .order(trhd1: :desc)
          .first
      end

      # rubocop:enable Layout/LineLength
      def render_invalid_year_error
        render json: { error: 'Invalid year' }, status: :unprocessable_entity
      end

      def render_invalid_dependents_error
        render json: { error: 'Invalid dependents' }, status: :unprocessable_entity
      end

      def render_zipcode_not_found_error
        render json: { error: 'Invalid zipcode' }, status: :unprocessable_entity
      end
    end
  end
end
