# frozen_string_literal: true

module Swagger
  module Schemas
    module Form526
      class DateRange
        include Swagger::Blocks

        swagger_schema :DateRange do
          property :from,
                   type: :string,
                   pattern: Swagger::Schemas::Form526::Form526SubmitV2::DATE_PATTERN,
                   example: '2019-10-XX'
          property :to,
                   type: :string,
                   pattern: Swagger::Schemas::Form526::Form526SubmitV2::DATE_PATTERN,
                   example: 'XXXX-12-31'
        end

        swagger_schema :DateRangeAllRequired do
          key :required, %i[to from]

          property :from,
                   type: :string,
                   pattern: Swagger::Schemas::Form526::Form526SubmitV2::DATE_PATTERN,
                   example: '2019-10-XX'
          property :to,
                   type: :string,
                   pattern: Swagger::Schemas::Form526::Form526SubmitV2::DATE_PATTERN,
                   example: 'XXXX-12-31'
        end
      end
    end
  end
end
