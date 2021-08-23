# frozen_string_literal: true

module MedicalCopays
  module VBS
    ##
    # Object for handling VBS request parameters
    #
    # @!attribute user
    #   @return [User]
    # @!attribute edipi
    #   @return [String]
    # @!attribute vha_facility_hash
    #   @return [Hash]
    # @!attribute errors
    #   @return [Array]
    class RequestData
      attr_reader :user, :edipi, :vha_facility_hash, :vista_account_numbers
      attr_accessor :errors

      ##
      # Builds a RequestData instance
      #
      # @param opts [Hash]
      # @return [RequestData] an instance of this class
      #
      def self.build(opts = {})
        new(opts)
      end

      ##
      # The schema for validating attribute data
      #
      # @return [Hash]
      #
      def self.statements_schema
        {
          'type' => 'object',
          'additionalProperties' => false,
          'required' => %w[edipi vistaAccountNumbers],
          'properties' => {
            'edipi' => {
              'type' => 'string'
            },
            'vistaAccountNumbers' => {
              'type' => 'array',
              'items' => {
                'type' => 'string',
                'minLength' => 16,
                'maxLength' => 16
              }
            }
          }
        }
      end

      ##
      # The options to be passed to {JSON::Validator#fully_validate}
      #
      # @return [Hash]
      #
      def self.schema_validation_options
        {
          errors_as_objects: true,
          version: :draft6
        }
      end

      def initialize(opts)
        @user = opts[:user]
        @edipi = user.edipi
        @vha_facility_hash = user.vha_facility_hash
        @vista_account_numbers = MedicalCopays::VistaAccountNumbers.build(data: vha_facility_hash)
        @errors = []
      end

      ##
      # The data to be posted to VBS
      #
      # @return [Hash]
      #
      def to_hash
        {
          edipi: edipi,
          vistaAccountNumbers: vista_account_numbers.list
        }
      end

      ##
      # Determine if the instance is valid based upon attribute data
      #
      # @return [Boolean]
      #
      def valid?
        errors = JSON::Validator.fully_validate(
          self.class.statements_schema,
          to_hash,
          self.class.schema_validation_options
        )

        errors.blank?
      end
    end
  end
end
