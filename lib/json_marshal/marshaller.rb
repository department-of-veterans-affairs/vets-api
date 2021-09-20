# frozen_string_literal: true

module JsonMarshal
  class Marshaller
    def self.dump(obj)
      obj.to_json
    end

    def self.load(attribute)
      JSON.parse(attribute) unless attribute.nil?
    end
  end
end
