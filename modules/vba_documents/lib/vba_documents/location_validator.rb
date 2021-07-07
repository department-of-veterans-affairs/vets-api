require 'json_schemer'
require 'uri'

module VBADocuments
  module LocationValidations
    SUPPORTED_EVENTS = %w(gov.va.developer.benefits.status_change)

    # Validates a subscription request for an upload submission.  Returns an object representing the subscription
    def validate_subscription(subscriptions)
      schema_path = Pathname.new('modules/vba_documents/spec/fixtures/subscriptions/webhook_subscriptions_schema.json')
      schemer_formats = {
        'valid_urls' => lambda { |urls, _schema_info| validate_urls(urls) }
      }
      schemer = JSONSchemer.schema(schema_path, formats: schemer_formats)
      unless schemer.valid?(subscriptions)
        example_data = JSON.parse(File.read('./modules/vba_documents/spec/fixtures/subscriptions/subscriptions.json'))
        raise ArgumentError.new({
                                  'Error' => 'Invalid subscription! Body must match the included example',
                                  'Example' => example_data
                                })
      end
      subscriptions
    end

    def validate_url(url)
      begin
        uri = URI(url)
      rescue URI::InvalidURIError
        raise ArgumentError.new({ 'Error' => "Invalid subscription! URI does not parse: #{url}" })
      end
      https = uri.scheme.eql? 'https'
      if !https && Settings.vba_documents.websockets.require_https
        raise ArgumentError.new({ 'Error' => "Invalid subscription! URL #{url} must be https!" })
      end

      true
    end

    def validate_urls(urls)
      valid = true
      urls.each do |url|
        valid &= validate_url(url)
      end
      valid
    end
  end
end
