# frozen_string_literal: true

module ClaimsApi
  class JsonMarshal
    def self.dump(obj)
      obj.to_json
    end

    def load(attribute)
      JSON.parse(attribute)
    end
  end
end
