# frozen_string_literal: true

module CheckIn
  module V2
    class AppointmentsController < CheckIn::ApplicationController
      before_action :before_logger, only: %i[index]
      after_action :after_logger, only: %i[index]

      def index
        head :not_implemented
      end

      def permitted_params
        params.permit(:start, :end, :_include)
      end

      private

      def start_date
        DateTime.parse(permitted_params[:start]).in_time_zone
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('start', params[:start])
      end

      def end_date
        DateTime.parse(permitted_params[:end]).in_time_zone
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('end', params[:end])
      end

      def statuses
        s = params[:statuses]
        s.is_a?(Array) ? s.to_csv(row_sep: nil) : s
      end
    end
  end
end
