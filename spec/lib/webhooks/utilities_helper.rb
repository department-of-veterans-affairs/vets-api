module Webhooks
  module Utilities
    class << self
      attr_accessor :suppress_registrations # thinly veiled global variable that the linter doesn't get whiny over.
    end
  end
end