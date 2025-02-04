# frozen_string_literal: true

module Rswag
  module Specs
    class SwaggerFormatter < ::RSpec::Core::Formatters::BaseTextFormatter
      def example_group_finished(notification)
        metadata = if RSPEC_VERSION > 2
                     notification.group.metadata
                   else
                     notification.metadata
                   end

        # !metadata[:document] won't work, since nil means we should generate
        # docs.
        return if metadata[ENV['DOCUMENTATION_ENVIRONMENT']&.to_sym] == false
        return if metadata[:document] == false
        return unless metadata.key?(:response)

        openapi_spec = @config.get_openapi_spec(metadata[:openapi_spec])

        puts "metadata[:swagger_doc] => #{metadata[:swagger_doc]}" if metadata[:swagger_doc].present?

        unless doc_version(openapi_spec).start_with?('2')
          # This is called multiple times per file!
          # metadata[:operation] is also re-used between examples within file
          # therefore be careful NOT to modify its content here.
          upgrade_request_type!(metadata)
          upgrade_servers!(openapi_spec)
          upgrade_oauth!(openapi_spec)
          upgrade_response_produces!(openapi_spec, metadata)
        end

        openapi_spec.deep_merge!(metadata_to_swagger(metadata))
      end

      # rubocop:disable Layout/LineLength, Style/CommentedKeyword, Metrics/MethodLength
      def stop(_notification = nil)
        @config.openapi_specs.each do |url_path, doc|
          unless doc_version(doc).start_with?('2')
            doc[:paths]&.each_pair do |_k, v|
              v.each_pair do |_verb, value|
                is_hash = value.is_a?(Hash)
                if is_hash && value[:parameters]
                  schema_param = value[:parameters]&.find { |p| %i[body formData].include?(p[:in]) && p[:schema] }
                  mime_list = value[:consumes] || doc[:consumes]
                  if value && schema_param && mime_list
                    value[:requestBody] = { content: {} } unless value.dig(:requestBody, :content)
                    value[:requestBody][:required] = true if schema_param[:required]
                    mime_list.each do |mime|
                      value[:requestBody][:content][mime] = { schema: schema_param[:schema] }.merge(request_examples(value)) # Changed line
                    end
                  end

                  value[:parameters].reject! { |p| %i[body formData].include?(p[:in]) }
                end
                remove_invalid_operation_keys!(value)
              end
            end
          end

          if relevant_path?(url_path) # Added conditional
            file_path = File.join(@config.openapi_root, url_path)
            dirname = File.dirname(file_path)
            FileUtils.mkdir_p dirname
            File.write(file_path, pretty_generate(doc))
            @output.puts "Swagger doc generated at #{file_path}"
          end # Added conditional
        end
      end
      # rubocop:enable Layout/LineLength, Style/CommentedKeyword, Metrics/MethodLength

      private # Added methods

      def request_examples(value)
        examples = value[:parameters]&.find { |p| %i[body formData].include?(p[:in]) && p[:examples] }
        if examples && examples[:examples]
          { examples: examples[:examples] }
        else
          {}
        end
      end

      def relevant_path?(url_path)
        url_path.include?(ENV.fetch('RAILS_MODULE'))
      end
    end
  end
end
