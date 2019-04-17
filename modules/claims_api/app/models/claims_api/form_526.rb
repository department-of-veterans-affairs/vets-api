# frozen_string_literal: true

module ClaimsApi
  class Form526
    attr_accessor :attributes

    def initialize(params = {})
      @attributes = params
    end

    def to_internal
      {
        "form526": attributes,
        "form526_uploads": [],
        "form4142": nil,
        "form0781": nil,
        "form8940": nil
      }.to_json
    end
  end
end
