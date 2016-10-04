# frozen_string_literal: true
require 'multi_json'

module SM
  class Parser
    attr_reader :parsed_json

    def initialize(parsed_json)
      @parsed_json = parsed_json
    end

    def parse!
      snakecase!

      @meta_attributes = split_meta_fields!
      @errors = @parsed_json.delete(:errors) || {}

      # TODO: replace _parsed_* with SM specific method to extract relevant attributes for each endpoint.
      data = parsed_triage || parsed_folders || normalize_message(parsed_messages) || parsed_categories

      @parsed_json = {
        data: data,
        errors: @errors,
        metadata: @meta_attributes
      }

      @parsed_json
    end

    def parsed_folders
      @parsed_json.key?(:system_folder) ? @parsed_json : @parsed_json[:folder]
    end

    def parsed_triage
      @parsed_json.key?(:triage_team_id) ? @parsed_json : @parsed_json[:triage_team]
    end

    def parsed_messages
      @parsed_json.key?(:recipient_id) ? @parsed_json : @parsed_json[:message]
    end

    def parsed_categories
      @parsed_json.key?(:message_category_type) ? @parsed_json : @parsed_json[:message_category_type]
    end

    def split_errors!
      @parsed_json.delete(:errors) || {}
    end

    def split_meta_fields!
      {}
    end

    def snakecase
      case @parsed_json
      when Array
        @parsed_json.map { |hash| underscore_symbolize(hash) }
      when Hash
        underscore_symbolize(@parsed_json)
      end
    end

    def snakecase!
      @parsed_json = snakecase
    end

    private

    def underscore_symbolize(hash)
      hash.deep_transform_keys { |k| k.underscore.to_sym }
    end

    def normalize_message(object)
      if object.is_a?(Array)
        object.map { |a| fix_attachments(a) }
      else
        fix_attachments(object)
      end
    end

    # TODO: Need to find out from MHV why this structure is not consistently returned
    # null is acceptable, but combination of Array or Hash is not
    def fix_attachments(message_json)
      return message_json.except(:attachments) unless message_json[:attachments].present?
      message_id = message_json[:id]
      attachments = Array.wrap(message_json[:attachments])
      # remove the outermost object name for attachment and inject message_id
      attachments = attachments.map do |attachment|
        attachment[:attachment].map { |e| e.merge(message_id: message_id) }
      end.flatten
      message_json.merge(attachments: attachments)
    end
  end
end
