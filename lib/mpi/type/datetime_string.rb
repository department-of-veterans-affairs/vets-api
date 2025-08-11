# frozen_string_literal: true

module MPI
  module Type
    class DateTimeString < ActiveModel::Type::Value
      def cast(value)
        value if value.is_a?(::String) && Time.parse(value).iso8601
      rescue ArgumentError
        nil
      end
    end
  end
end

ActiveModel::Type.register(:mpi_datetime_string, MPI::Type::DateTimeString)
