# frozen_string_literal: true

module FormDurations
  ##
  # A service object for coordinating the efforts to determine an expiration duration
  # for a given form. The Object goes about accomplishing this in a declarative manner
  # via its public interface and hides the implementation details in a few private methods
  #
  # @!attribute form_id
  #   @return [String]
  # @!attribute days_till_expires
  #   @return [ActiveSupport::Duration]
  # @!attribute config
  #   @return [OpenStruct]
  # @!attribute duration_instance
  #   @return a matching duration object
  class Worker
    ##
    # The Regex matcher for getting the form name from a form_id,
    # including custom form_ids. Example: Get HC-QSTNR from the
    # form_id HC-QSTNR_123abc
    #
    REGEXP_ID_MATCHER = /^[^_]*/
    ##
    # The default Registry key to use if none of the given form_ids match
    #
    STANDARD_DURATION_NAME = 'standard'
    ##
    # A Registry of UI Forms and their configuration key/values
    # The Worker class bears the responsibility for maintaining the Hash
    #
    REGISTRY = {
      'standard' => { klazz: StandardDuration, static: true },
      '21-526ez' => { klazz: AllClaimsDuration, static: true },
      'hc-qstnr' => { klazz: CustomDuration, static: false }
    }.freeze

    attr_reader :form_id, :days_till_expires, :config, :duration_instance

    ##
    # Builds a FormDurations::Worker instance from given options
    #
    # @param opts [Hash] a set of key value pairs.
    # @return [FormDurations::Worker] an instance of this class
    #
    def self.build(opts = {})
      new(**opts)
    end

    def initialize(form_id: nil, days_till_expires: nil)
      @form_id = form_id
      @days_till_expires = days_till_expires
      @config = build_duration_config
      @duration_instance = build_duration_instance
    end

    ##
    # Gets the expiration duration for a given form
    #
    # @return [ActiveSupport::Duration] an instance of ActiveSupport::Duration
    #
    def get_duration
      duration_instance.span
    end

    ##
    # List of imperative methods that hide the Worker classes implementation details
    # These could potentially be moved into their own Class in the future if necessary
    #
    private

    def build_duration_instance
      if static_duration?
        config.klazz.build
      else
        config.klazz.build(normalized_days_till_expires)
      end
    end

    def static_duration?
      config.static == true
    end

    def normalized_days_till_expires
      @normalized_days_till_expires ||= days_till_expires.to_s.to_i
    end

    def form_name
      normalized = form_id.to_s.downcase.match(REGEXP_ID_MATCHER)[0]

      return STANDARD_DURATION_NAME unless REGISTRY.key?(normalized)

      normalized
    end

    def build_duration_config
      OpenStruct.new(REGISTRY.fetch(form_name))
    end
  end
end
