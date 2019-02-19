
# frozen_string_literal: true

module ClaimsApi
  class Form526
    include Virtus.model
    attribute :data, Hash

    def to_internal
      {
        "form526": @data,
        "form526_uploads": [],
        "form4142": nil,
        "form0781": nil,
        "form8940": nil
      }.to_json
    end
  end
end
