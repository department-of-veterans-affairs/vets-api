# frozen_string_literal: true

require 'lighthouse/facilities/client'

module MedicalCopays
  ##
  # Object for building a list of the user's zero balance statements
  #
  # @!attribute facility_hash
  # @!attribute statements
  # @return [Array<Hash>]
  #
  class ZeroBalanceStatements
    attr_reader :facility_hash, :statements
    attr_accessor :facilities

    ##
    # Builds a ZeroBalanceStatements instance
    #
    # @param opts [Hash]
    # @return [ZeroBalanceStatements] an instance of this class
    #
    def self.build(opts = {})
      new(opts)
    end

    def initialize(opts)
      @facility_hash = opts[:facility_hash]
      @statements = opts[:statements]
      @facilities = get_facilities || []
    end

    ##
    # Format collection of facilities to match VBS response
    #
    # @return [Array<Hash>]
    #
    def list
      facilities.map do |facility|
        {
          'pH_AMT_DUE' => 0,
          'pS_STATEMENT_DATE' => Time.zone.today.strftime('%m%d%Y'),
          'station' => {
            'facilitY_NUM' => facility['id'].sub('vha_', ''),
            'city' => facility['address']['physical']['city'].upcase
          }
        }
      end
    end

    private

    ##
    # The list of vista keys associated with the user's profile
    #
    # @return [Array<String>]
    #
    def facilities_ids
      facility_hash&.keys
    end

    ##
    # The list of facility ids found from the VBS response
    #
    # @return [Array<String>]
    #
    def statements_facilities_ids
      statements.pluck('pS_FACILITY_NUM')
    end

    ##
    # The unique list of facilities with zero balance
    #
    # @return [Array<String>]
    #
    def zero_balance_facilities_ids
      facilities_ids.uniq - statements_facilities_ids unless facilities_ids.nil?
    end

    ##
    # Formatted object to pass to the Lightouse API
    #
    # @return [Hash]
    #
    def request_data
      vha_formatted_ids = zero_balance_facilities_ids.map { |i| i.dup.prepend('vha_') }.join(',')
      { ids: vha_formatted_ids }
    end

    ##
    # Get facilities that have zero balance from Lighthouse
    #
    # @return [Array<Lighthouse::Facilities::Facility>]
    #
    def get_facilities
      facility_api.get_facilities(request_data) if zero_balance_facilities_ids.present?
    rescue Common::Exceptions::BackendServiceException
      []
    end

    def facility_api
      Lighthouse::Facilities::Client.new
    end
  end
end
