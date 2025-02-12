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
      attr_accessor :display, :test_code, :date_completed, :sample_site, :encoded_data, :location

      def initialize(display:, test_code:, date_completed:, sample_site:, encoded_data:, location:)
        @display = display
        @test_code = test_code
        @date_completed = date_completed
        @sample_site = sample_site
        @encoded_data = encoded_data
        @location = location
      end
    end
  end
end
