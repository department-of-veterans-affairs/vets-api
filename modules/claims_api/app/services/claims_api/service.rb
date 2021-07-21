# frozen_string_literal: true

module ClaimsApi
  class Service
    def self.process(**args)
      new(args).process
    end
  end
end
