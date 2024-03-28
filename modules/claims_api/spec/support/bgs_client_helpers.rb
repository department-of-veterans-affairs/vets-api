# frozen_string_literal: true

VCR.configure do |config|
  config.register_request_matcher :xml_body do |req_a, req_b|
    xml_a = Nokogiri::XML(req_a.body, &:noblanks).canonicalize
    xml_b = Nokogiri::XML(req_b.body, &:noblanks).canonicalize
    xml_a == xml_b
  end
end

module BGSClientHelpers
  VCR_OPTIONS = {match_requests_on: [:method, :uri, :xml_body]}
  VCR_DIRECTORY_PATH = 'bgs'

  def use_bgs_cassette(&)
    metadata = RSpec.current_example.metadata[:bgs_client].to_h
    service, operation = metadata.values_at(:service, :operation)

    if service.blank? || operation.blank?
      raise ArgumentError, <<~HEREDOC
        Must provide spec metadata of the form:
          {bgs_client: {service: 'service', operation: 'operation'}}
      HEREDOC
    end

    filename = RSpec.current_example.full_description
    name = File.join(VCR_DIRECTORY_PATH, service, operation, filename)
    VCR.use_cassette(name, VCR_OPTIONS, &)
  end
end

RSpec.configure do |config|
  config.include BGSClientHelpers, type: :bgs_client
end
