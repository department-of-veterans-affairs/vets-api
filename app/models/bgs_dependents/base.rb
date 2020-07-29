# frozen_string_literal: true

module BGSDependents
  class Base < Common::Base
    def format_date(date)
      return nil if date.nil?

      Date.parse(date).to_time.iso8601
    end
  end
end
