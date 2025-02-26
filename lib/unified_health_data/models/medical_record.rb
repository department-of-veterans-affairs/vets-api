# frozen_string_literal: true

module UnifiedHealthData
  class MedicalRecord
    attr_accessor :id, :type, :attributes

    def initialize(id:, type:, attributes:)
      @id = id
      @type = type
      @attributes = attributes
    end

    # rubocop:disable Metrics/ParameterLists
    class Attributes
      attr_accessor :display, :test_code, :date_completed, :sample_site,
                    :encoded_data, :location, :ordered_by, :observations

      def initialize(display:, test_code:, date_completed:, sample_site:,
                     encoded_data:, location:, ordered_by:, observations:)
        @display = display
        @test_code = test_code
        @date_completed = date_completed
        @sample_site = sample_site
        @encoded_data = encoded_data
        @location = location
        @ordered_by = ordered_by
        @observations = observations
      end

      class Observation
        attr_accessor :test_code, :value_quantity,
                      :reference_range, :status, :comments

        def initialize(test_code:, value_quantity:, reference_range:, status:, comments:)
          @test_code = test_code
          @value_quantity = value_quantity
          @reference_range = reference_range
          @status = status
          @comments = comments
        end
      end
    end
  end
  # rubocop:enable Metrics/ParameterLists
end
