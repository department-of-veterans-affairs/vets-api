# frozen_string_literal: true

module Rswag
  module Specs
    class SwaggerFormatter < ::RSpec::Core::Formatters::BaseTextFormatter
      # rubocop:disable Metrics/BlockNesting, Layout/LineLength, Style/CommentedKeyword, Metrics/MethodLength
      def stop(_notification = nil)
        @config.swagger_docs.each do |url_path, doc|
          unless doc_version(doc).start_with?('2')
            doc[:paths]&.each_pair do |_k, v|
              v.each_pair do |_verb, value|
                is_hash = value.is_a?(Hash)
                if is_hash && value[:parameters]
                  schema_param = value[:parameters]&.find { |p| (p[:in] == :body || p[:in] == :formData) && p[:schema] }
                  mime_list = value[:consumes] || doc[:consumes]
                  if value && schema_param && mime_list
                    value[:requestBody] = { content: {} } unless value.dig(:requestBody, :content)
                    value[:requestBody][:required] = true if schema_param[:required]
                    mime_list.each do |mime|
                      value[:requestBody][:content][mime] = { schema: schema_param[:schema] }.merge(request_examples(value)) # Changed line
                    end
                  end

                  value[:parameters].reject! { |p| p[:in] == :body || p[:in] == :formData }
                end
                remove_invalid_operation_keys!(value)
              end
            end
          end

          if relevant_path?(url_path) # Added conditional
            file_path = File.join(@config.swagger_root, url_path)
            dirname = File.dirname(file_path)
            FileUtils.mkdir_p dirname unless File.exist?(dirname)
            File.open(file_path, 'w') do |file|
              file.write(pretty_generate(doc))
            end
            @output.puts "Swagger doc generated at #{file_path}"
          end # Added conditional
        end
      end
      # rubocop:enable Metrics/BlockNesting, Layout/LineLength, Style/CommentedKeyword, Metrics/MethodLength

      private # Added methods

      def request_examples(value)
        examples = value[:parameters]&.find { |p| (p[:in] == :body || p[:in] == :formData) && p[:examples] }
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
