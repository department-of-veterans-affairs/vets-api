# frozen_string_literal: true

RSpec.configure do |config|
  config.around(:each, :bgs) do |example|
    metadata = example.metadata[:bgs].to_h
    service, operation = metadata.values_at(:service, :operation)

    if service.blank? || operation.blank?
      raise ArgumentError, <<~HEREDOC
        Must provide spec metadata of the form:
          {bgs: {service: 'service', operation: 'operation'}}
      HEREDOC
    end

    name = File.join('bgs', service, operation, example.full_description)
    options = {match_requests_on: [:method, :uri, :xml_body]}

    VCR.use_cassette(name, options) do
      example.run
    end
  end
end

VCR.configure do |config|
  config.register_request_matcher :xml_body do |req_a, req_b|
    # I suspect that this is not a correct implementation of XML equality but
    # that there is a correct implementation of it somewhere out there.
    xml_a = Nokogiri::XML(req_a.body, &:noblanks).canonicalize
    xml_b = Nokogiri::XML(req_b.body, &:noblanks).canonicalize
    xml_a == xml_b
  end
end
