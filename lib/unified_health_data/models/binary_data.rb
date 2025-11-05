# frozen_string_literal: true

require 'vets/model'

module UnifiedHealthData
  class BinaryData
    include Vets::Model

    attribute :content_type, String
    attribute :binary, String # base64 encoded string
  end
end
