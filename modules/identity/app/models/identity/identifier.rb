# frozen_string_literal: true

module Identity
  class Identifier
    attr_accessor :value, :kind

    VALID_KINDS = %w(idme participant mhv mhv_correlation dslogon sec edipi birls)

    # Parse a set of key / value pairs from SAML or MPI.
    def self.parse(identifiers=[])
      identifiers.each do |identifier|
      end
    end

    def initialize(attrs={})
      @value = attrs[:value]
      @type  = attrs[:kind]
    end
  end
end
