# frozen_string_literal: true

module Identity
  class Phone
    attr_accessor :kind, :number

    VALID_KINDS = %w(home mobile work)

    def initialize(attrs={})
      @kind   = attrs[:kind]
      @number = attrs[:number]
    end

  end
end