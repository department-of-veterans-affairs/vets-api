
# frozen_string_literal: true

module ClaimsApi
  class Form526
    include Virtus.model
    attribute :data, Hash

    def to_internal
      {
        "form526": @data,
        "form526_uploads": [],
        "form4142": null,
        "form0781": null,
        "form8940": null
      }
    end
  end
end
