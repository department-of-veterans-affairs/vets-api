# frozen_string_literal: true

module VAOS
  module Anonymizers
    # Anonymizes the ICN present in a given URI object by substituting a SHA256 digest for the ICN.
    # If an ICN is not present in the URL,  it would simply return the original URI.
    #
    # @param url [URI] URI in which ICN needs to be anonymized.
    #
    # @return [URI] URI with anonymized ICN (If present), original URI otherwise.
    #
    def self.anonymize_uri_icn(uri)
      return nil if uri.nil?

      # Extract the patient ICN from the URL
      url = uri.to_s
      match = url[/(\d{10}V\d{6})/]

      return uri unless match

      digest = Digest::SHA256.hexdigest(match)
      url.gsub!(match, digest)
      URI(url)
    end
  end
end
