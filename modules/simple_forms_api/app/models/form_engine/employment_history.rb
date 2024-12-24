# frozen_string_literal: true

module SimpleFormsApi
  module FormEngine
    class EmploymentHistory
      attr_reader :date_ended, :date_started, :hours_per_week, :lost_time, :type_of_work

      def initialize(data)
        @data = data
        @date_ended = data.dig('date_range', 'to')
        @date_started = data.dig('date_range', 'from')
        @hours_per_week = data['hours_per_week']
        @lost_time = data['lost_time']
        @type_of_work = data['type_of_work']
      end

      def highest_income
        ActiveSupport::NumberHelper.number_to_currency(@data['highest_income'])
      end
    end
  end
end
