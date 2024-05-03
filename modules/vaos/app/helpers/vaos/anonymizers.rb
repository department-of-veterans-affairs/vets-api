# frozen_string_literal: true

module VAOS
  module Anonymizers
    # Anonymizes the ICNs (Integration Control Number) in a given message. It scans the message for ICNs,
    # which are identified by a specific pattern (\d{10}V\d{6}), and replaces each ICN with
    # a SHA256 digest. If the message is nil, the method returns nil.
    # If no ICNs are found, the method returns the original message.
    #
    # @param message [String] The message in which ICNs need to be anonymized.
    #
    # @return [String] The message with anonymized ICNs, or the original message if no ICNs were found.
    def self.anonymize_icns(message)
      return nil if message.nil?

      # find all ICNs
      matches = message.scan(/(\d{10}V\d{6})/).flatten.uniq

      anonymized_message = message.dup

      matches.each do |match|
        digest = Digest::SHA256.hexdigest(match)
        anonymized_message.gsub!(match, digest)
      end

      anonymized_message
    end
  end
end
