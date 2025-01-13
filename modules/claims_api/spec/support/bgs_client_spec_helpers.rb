# frozen_string_literal: true

module BGSClientSpecHelpers
  # If one finds this request matcher useful elsewhere in the future,
  # Rather than using a callable custom request matcher:
  #   https://benoittgt.github.io/vcr/#/request_matching/custom_matcher?id=use-a-callable-as-a-custom-request-matcher
  # This could instead be registered as a named custom request matcher:
  #   https://benoittgt.github.io/vcr/#/request_matching/custom_matcher?id=register-a-named-custom-matcher
  # Called `:body_as_xml` as inspired by `:body_as_json`:
  #   https://benoittgt.github.io/vcr/#/request_matching/body_as_json?id=matching-on-body
  body_as_xml_matcher =
    lambda do |req_actual, req_expected|
      # I suspect that this is not a fully correct implementation of XML
      # equality but that there is a fully correct implementation of it
      # somewhere out there.
      xml_actual = Nokogiri::XML(req_actual.body, &:noblanks).canonicalize
      xml_expected = Nokogiri::XML(req_expected.body, &:noblanks).canonicalize
      xml_actual == xml_expected
    end

  VCR_OPTIONS = {
    match_requests_on: [
      :method, :uri, :headers,
      body_as_xml_matcher.freeze
    ].freeze
  }.freeze

  ##
  # This convenience method affords a handful of quality of life improvements
  # for developing BGS service action wrappers. It makes development a less
  # manual process. It also turns VCR cassettes into a human readable resource
  # that documents the behavior of BGS.
  #
  # In order to take advantage of this method, you will need to have supplied,
  # to your example or example group, metadata of this form:
  #   `{ bgs: { service: "service", action: "action" } }`.
  #
  # Then, HTTP interactions that occur within the block supplied to this method
  # will be captured by VCR cassettes that have the following convenient
  # properties:
  #   - They will be nicely organized at `claims_api/bgs/:service/:action/:name`
  #   - Cassette matching will be done on canonicalized XML bodies, so
  #     reformatting cassettes for human readability won't defeat matching
  #
  def use_bgs_cassette(name, options = {}, &)
    metadata = RSpec.current_example.metadata[:bgs].to_h
    service, action = metadata.values_at(:service, :action)

    if service.blank? || action.blank?
      raise ArgumentError, <<~HEREDOC
        Must provide spec metadata of the form:
          `{ bgs: { service: "service", action: "action" } }'
      HEREDOC
    end

    # Force this option to `false` to "eliminate" it from the method signature
    # because `true` is incompatible with the whole point of this method.
    options.merge!(use_spec_name_prefix: false)
    name = File.join('claims_api/bgs', service, action, name)

    use_soap_cassette(name, options, &)
  end

  def use_soap_cassette(name, options = {}, &)
    options.with_defaults!(
      **VCR_OPTIONS,
      use_spec_name_prefix: false
    )

    options.delete(:use_spec_name_prefix) and
      name = spec_name_prefix / name

    VCR.use_cassette(name, options, &)
  end

  def spec_name_prefix
    caller.each do |call|
      call = call.split(':').first
      next unless call.end_with?('_spec.rb')

      call.delete_prefix!((ClaimsApi::Engine.root / 'spec/').to_s)
      call.delete_suffix!('.rb')
      return Pathname('claims_api') / call
    end
  end
end

RSpec.configure do |config|
  config.include BGSClientSpecHelpers, :bgs
end
