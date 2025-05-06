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
      @city = data.dig('address', 'city')
      @country = data.dig('address', 'country')
      @date_ended = format_date(data.dig('date_range', 'to'))
      @date_started = format_date(data.dig('date_range', 'from'))
      @highest_income = ActiveSupport::NumberHelper.number_to_currency(data['highest_income'])
      @hours_per_week = data['hours_per_week']
      @lost_time = data['lost_time']
      @name = data['name']
      @postal_code = data.dig('address', 'postal_code')
      @state = data.dig('address', 'state')
      @street = data.dig('address', 'street')
      @type_of_work = data['type_of_work']

      @name_and_address = format_name_and_address
    end
  end
end
