# frozen_string_literal: true

module UnifiedHealthData
  class MedicalRecord
    attr_accessor :id, :type, :display, :test_code, :date_completed, :sample_site, :encoded_data, :location

    def initialize(id:, type:, display:, test_code:, date_completed:, sample_site:, encoded_data:, location:)
      @id = id
      @type = type
      @display = display
      @test_code = test_code
      @date_completed = date_completed
      @sample_site = sample_site
      @encoded_data = encoded_data
      @location = location
    end
  end
end
