# frozen_string_literal: true

module FormEngine
  class EmploymentHistory
    attr_reader :date_ended,
                :date_started,
                :highest_income,
                :hours_per_week,
                :lost_time,
                :name_and_address,
                :type_of_work

    def initialize(data)
      @data = data

      set_ivars if data.present?
    end

    private

    attr_reader :city, :country, :data, :name, :postal_code, :state, :street

    def format_date(date)
      return nil if date.nil?

      date_arr = date.split('-')

      "#{date_arr[1]}/#{date_arr[2]}/#{date_arr[0]}"
    end

    def format_name_and_address
      output = []

      output << name
      output << street
      output << "#{city}, #{state} #{postal_code}"
      output << IsoCountryCodes.find(country).name

      output.join('\n')
    end

    def set_ivars
      @city = data.dig('employer_address', 'city')
      @country = data.dig('employer_address', 'country')
      @date_ended = format_date(data.dig('employment_dates', 'to'))
      @date_started = format_date(data.dig('employment_dates', 'from'))
      @highest_income = format_currency(data['highest_gross_income_per_month'])
      @hours_per_week = data['hours_per_week']
      @lost_time = data['lost_time_from_illness']
      @name = data['employer_name']
      @postal_code = data.dig('employer_address', 'postal_code')
      @state = data.dig('employer_address', 'state')
      @street = data.dig('employer_address', 'street')
      @type_of_work = data['type_of_work']

      @name_and_address = format_name_and_address
    end

    def format_currency(amount)
      return nil unless amount

      ActiveSupport::NumberHelper.number_to_currency(amount)
    end
  end
end
