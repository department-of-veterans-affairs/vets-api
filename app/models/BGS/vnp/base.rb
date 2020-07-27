# frozen_string_literal: true

module BGS
  module Vnp
    class Base
      def format_date(date)
        return nil if date.nil?

        Date.parse(date).to_time.iso8601
      end
    end
  end
end
