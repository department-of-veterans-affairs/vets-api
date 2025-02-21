# frozen_string_literal: true

module UnifiedHealthData
  class MedicalRecord
    attr_accessor :id, :type, :attributes

    def initialize(id:, type:, attributes:)
      @id = id
      @type = type
      @attributes = attributes
    end

    class Attributes
      attr_accessor :display, :test_code, :date_completed, :sample_site, :encoded_data, :location, :observations

      def initialize(display:, test_code:, date_completed:, sample_site:, encoded_data:, location:, observations:)
        @display = display
        @test_code = test_code
        @date_completed = date_completed
        @sample_site = sample_site
        @encoded_data = encoded_data
        @location = location
        @observations = observations
      end

      class Observation
        attr_accessor :test_code, :sample_site, :encoded_data, :value_quantity, :reference_range, :status, :comments

        def initialize(test_code:, sample_site:, encoded_data:, value_quantity:, reference_range:, status:, comments:)
          @test_code = test_code
          @sample_site = sample_site
          @encoded_data = encoded_data
          @value_quantity = value_quantity
          @reference_range = reference_range
          @status = status
          @comments = comments
        end
      end
    end

  end
end
