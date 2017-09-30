# frozen_string_literal: true

module EMIS
  module Models
    class Retirement
      include Virtus.model

      attribute :service_code, String
      attribute :begin_date, Date
      attribute :end_date, Date
      attribute :termination_reason_code, String
    end
  end
end
