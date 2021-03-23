# frozen_string_literal: true

module Identity
  class FindMpiProfile
    attr_accessor :identity

    def initialize(uuid)
      @uuid = uuid
    end

    def call
      attrs = {}
      identity = ::Identity::Identity.new(attrs)
      return identity
    end
  end
end
