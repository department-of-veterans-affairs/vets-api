# frozen_string_literal: true

module VAOS
  module V2
    class EpsDraftAppointmentError < StandardError
      attr_reader :title, :detail, :status_code

      def initialize(detail, title: 'Appointment creation failed', status_code: :unprocessable_entity)
        @title = title
        @detail = detail
        @status_code = status_code
        super(detail)
      end
    end
  end
end
