# frozen_string_literal: true
require 'multi_json'

module SM
  #####################################################################################################################
  ## Parser
  ## Converts a hash having camel-cased string keys into snakecase symbolized keys.
  ##
  ## JSON from MHV -> JSON load                                   -> Parser.parse!
  ## String        -> Ruby camelcased string keys-hash/hash-array -> Ruby symbol keys snakecased-hash/hash-array
  #####################################################################################################################
  class Parser
    attr_reader :parsed_json

    ###################################################################################################################
    ## initialize
    ###################################################################################################################
    def initialize(parsed_json)
      @parsed_json = parsed_json
    end

    ###################################################################################################################
    ## parse!
    ## Parses json converting camel-cased string keys into snake-cased symbols. Additionally, moves metadata and errors
    ## into their own objects.
    ###################################################################################################################
    def parse!
      snakecase!

      @meta_attributes = split_meta_fields!
      @errors = @parsed_json.delete(:errors) || {}

      # TODO: replace _parsed_* with SM specific method to extract relevant attributes for each endpoint.
      data = parsed_triage || parsed_folders || parsed_messages || parsed_categories

      @parsed_json = {
        data: data,
        errors: @errors,
        metadata: @meta_attributes
      }

      @parsed_json
    end

    ###################################################################################################################
    ## parsed_folders
    ## Examines the parsed_json for the presence of a key unique to a folder.
    ###################################################################################################################
    def parsed_folders
      if @parsed_json.is_a?(Hash)
        @parsed_json.key?(:system_folder) ? @parsed_json : @parsed_json[:folder]
      elsif @parsed_json.is_a?(Array) && @parsed_json.first.key?(:system_folder)
        @parsed_json
      end
    end

    ###################################################################################################################
    ## parsed_triage
    ## Examines the parsed_json for the presence of a key unique to a triage team.
    ###################################################################################################################
    def parsed_triage
      if @parsed_json.is_a?(Hash)
        @parsed_json.key?(:triage_team_id) ? @parsed_json : @parsed_json[:triage_team]
      elsif @parsed_json.is_a?(Array) && @parsed_json.first.key?(:triage_team_id)
        @parsed_json
      end
    end

    ###################################################################################################################
    ## parsed_messages
    ## Examines the parsed_json for the presence of a key unique to a message.
    ###################################################################################################################
    def parsed_messages
      if @parsed_json.is_a?(Hash)
        @parsed_json.key?(:recipient_id) ? @parsed_json : @parsed_json[:message]
      elsif @parsed_json.is_a?(Array) && @parsed_json.first.key?(:recipient_id)
        @parsed_json
      end
    end

    ###################################################################################################################
    ## parsed_categories
    ## Examines the parsed_json for the presence of a key unique to a message.
    ###################################################################################################################
    def parsed_categories
      if @parsed_json.is_a?(Hash)
        @parsed_json.key?(:message_category_type) ? @parsed_json : @parsed_json[:message_category_type]
      elsif @parsed_json.is_a?(Array) && @parsed_json.first.key?(:message_category_type)
        @parsed_json
      end
    end

    ###################################################################################################################
    ## split_errors!
    ## Moves error information into its own object.
    ###################################################################################################################
    def split_errors!
      @parsed_json.delete(:errors) || {}
    end

    ###################################################################################################################
    ## split_meta_fields!
    ## Moves medadata from the main json body to its own.
    ###################################################################################################################
    def split_meta_fields!
      # Move metadata from main body of json e.g.,
      # updated_at = @parsed_json.delete(:last_updated_time) || @parsed_json.delete(:last_updatedtime)
      # { updated_at: updated_at }

      {}
    end

    ###################################################################################################################
    ## snakecase
    ## Converts the camel-cased json keys into ruby snake-cased symbolized keys.
    ###################################################################################################################
    def snakecase
      case @parsed_json
      when Array
        @parsed_json.map { |hash| underscore_symbolize(hash) }
      when Hash
        underscore_symbolize(@parsed_json)
      end
    end

    ###################################################################################################################
    ## snakecase!
    ## Self-modifying wrapper for snake-case.
    ###################################################################################################################
    def snakecase!
      @parsed_json = snakecase
    end

    private

    ###################################################################################################################
    ## underscore_symbolize
    ## Uses ActiveSupport's deep_transform_keys method to convert camel-cased json keys into snake-cased keys.
    ###################################################################################################################
    def underscore_symbolize(hash)
      hash.deep_transform_keys { |k| k.underscore.to_sym }
    end
  end
end
