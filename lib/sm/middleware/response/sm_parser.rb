# frozen_string_literal: true

module SM
  module Middleware
    module Response
      ##
      # Middleware class responsible for customizing MHV SM response parsing
      #
      class SMParser < Faraday::Response::Middleware
        ##
        # Override the Faraday #on_complete method to filter body through custom #parse
        # @param env [Faraday::Env] the request environment
        # @return [Faraday::Env]
        #
        def on_complete(env)
          return unless env.response_headers['content-type']&.match?(/\bjson/)

          env[:body] = parse(env.body) if env.body.present?
        end

        private

        def parse(body = nil)
          @parsed_json = body
          @meta_attributes = split_meta_fields!
          @errors = @parsed_json.delete(:errors) || {}

          data =  parsed_threads_object ||
                  preferences     ||
                  parsed_triage   ||
                  parsed_folders  ||
                  normalize_message(parsed_messages) ||
                  parsed_categories ||
                  parsed_signature
          @parsed_json = {
            data: data,
            errors: @errors,
            metadata: @meta_attributes
          }

          @parsed_json
        end

        def parsed_threads
          @parsed_json.is_a?(Array) && @parsed_json.each { |t| return false unless t.key?(:thread_id) }
        end

        def preferences
          %i[notify_me 0].any? { |k| @parsed_json.key?(k) } ? @parsed_json : nil
        end

        def parsed_threads_object
          @parsed_json.is_a?(Array) && @parsed_json.each { |t| return false unless t.key?(:thread_id) }
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

        def parsed_signature
          @parsed_json.key?(:signature_name) ? @parsed_json : @parsed_json[:signature_name]
        end

        def split_errors!
          @parsed_json.delete(:errors) || {}
        end

        def split_meta_fields!
          {}
        end

        def normalize_message(object)
          return object if object.blank?

          if object.is_a?(Array)
            object.map { |a| fix_attachments(a) }
          else
            fix_attachments(object)
          end
        end

        def fix_attachments(message_json)
          return message_json.except(:attachments) if message_json[:attachments].blank?

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
  end
end

Faraday::Response.register_middleware sm_parser: SM::Middleware::Response::SMParser
