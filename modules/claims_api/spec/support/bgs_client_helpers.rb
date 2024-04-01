# frozen_string_literal: true

module BGSClientHelpers
  # If one finds this request matcher useful elsewhere in the future,
  # Rather than using a callable custom request matcher:
  #   https://benoittgt.github.io/vcr/#/request_matching/custom_matcher?id=use-a-callable-as-a-custom-request-matcher
  # This could instead be registered as a named custom request matcher:
  #   https://benoittgt.github.io/vcr/#/request_matching/custom_matcher?id=register-a-named-custom-matcher
  # Called `:body_as_xml` as inspired by `:body_as_json`:
  #   https://benoittgt.github.io/vcr/#/request_matching/body_as_json?id=matching-on-body
  body_as_xml_matcher =
    lambda do |req_a, req_b|
      # I suspect that this is not a correct implementation of XML equality but
      # that there is a correct implementation of it somewhere out there.
      xml_a = Nokogiri::XML(req_a.body, &:noblanks).canonicalize
      xml_b = Nokogiri::XML(req_b.body, &:noblanks).canonicalize
      xml_a == xml_b
    end

  VCR_OPTIONS = {
    erb: true,

    # Consider matching on `:headers` too?
    match_requests_on: [
      :method, :uri,
      body_as_xml_matcher.freeze
    ].freeze
  }.freeze

  def use_bgs_cassette(&)
    example = RSpec.current_example
    metadata = example.metadata[:bgs].to_h
    service, operation = metadata.values_at(:service, :operation)

    if service.blank? || operation.blank?
      raise ArgumentError, <<~HEREDOC
        Must provide spec metadata of the form:
          { bgs: { service: 'service', operation: 'operation' } }
      HEREDOC
    end

    name = File.join('bgs', service, operation, example.full_description)
    VCR.use_cassette(name, VCR_OPTIONS, &)
  end
end

RSpec.configure do |config|
  config.include BGSClientHelpers, :bgs
end
