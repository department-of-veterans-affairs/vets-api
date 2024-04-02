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
      # I suspect that this is not a fully correct implementation of XML
      # equality but that there is a fully correct implementation of it
      # somewhere out there.
      xml_a = Nokogiri::XML(req_a.body, &:noblanks).canonicalize
      xml_b = Nokogiri::XML(req_b.body, &:noblanks).canonicalize
      xml_a == xml_b
    end

  VCR_OPTIONS = {
    # Allows the same cassette to match in different test environments when the
    # base URL for BGS differs between them.
    #   https://benoittgt.github.io/vcr/#/cassettes/dynamic_erb?id=pass-arguments-to-the-erb-using-gt-
    erb: { bgs_base_url: Settings.bgs.url },

    # Consider matching on `:headers` too?
    match_requests_on: [
      :method, :uri,
      body_as_xml_matcher.freeze
    ].freeze
  }.freeze

  # This convenience method affords a handful of quality of life improvements
  # for developing BGS service operation wrappers. It makes development a less
  # manual process. It also turns VCR cassettes into a human readable resource
  # that documents the behavior of BGS.
  #
  # In order to take advantage of this method, you will need to have supplied,
  # to your example or example group, metadata of this form:
  #   `{ bgs: { service: "service", operation: "operation" } }`.
  #
  # Then, HTTP interactions that occur within the block supplied to this method
  # will be captured by VCR cassettes that have the following convenient
  # properties:
  #   - They will be nicely organized at `bgs/:service/:operation/:name`
  #   - Cassette matching will be done on canonicalized XML bodies, so
  #     reformatting cassettes for human readability won't defeat matching
  #   - ERB templating will be enabled with a value `bgs_base_url` supplied so
  #     that the same cassette will function without modification in multiple
  #     environments like CI and locally
  def use_bgs_cassette(name, &)
    metadata = RSpec.current_example.metadata[:bgs].to_h
    service, operation = metadata.values_at(:service, :operation)

    if service.blank? || operation.blank?
      raise ArgumentError, <<~HEREDOC
        Must provide spec metadata of the form:
          `{ bgs: { service: "service", operation: "operation" } }'
      HEREDOC
    end

    name = File.join('bgs', service, operation, name)
    VCR.use_cassette(name, VCR_OPTIONS, &)
  end
end

RSpec.configure do |config|
  config.include BGSClientHelpers, :bgs
end
