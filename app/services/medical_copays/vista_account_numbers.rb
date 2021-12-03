# frozen_string_literal: true

module MedicalCopays
  ##
  # Object for building a list of the user's vista account numbers
  #
  # @!attribute data
  #   @return [Hash]
  class VistaAccountNumbers
    attr_reader :data

    ##
    # Builds a VistaAccountNumbers instance
    #
    # @param opts [Hash]
    # @return [VistaAccountNumbers] an instance of this class
    #
    def self.build(opts = {})
      new(opts)
    end

    def initialize(opts)
      @data = opts[:data]
    end

    ##
    # The calculated list of Vista Account Numbers for the VBS service
    #
    # @return [Array]
    #
    def list
      return default if data.blank?

      data.each_with_object([]) do |(key, values), accumulator|
        next if values.blank?

        values.each do |id|
          accumulator << vista_account_id(key, id)
        end
      end
    end

    ##
    # Create the Vista Account Number using the facility id,
    # the associated vista id and the calculated number of '0's
    # required between the facility id and the vista id.
    #
    # @return [String]
    #
    def vista_account_id(key, id)
      offset = 16 - (key + id).length
      padding = '0' * offset if offset >= 0

      "#{key}#{padding}#{id}".to_i
    end

    ##
    # Default array and value if the user's `vha_facility_hash` is blank
    #
    # @return [Array]
    #
    def default
      [0]
    end
  end
end
