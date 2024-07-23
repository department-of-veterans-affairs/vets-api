# frozen_string_literal: true

module Vye
  class DateAttributeSerializer
    def self.load(v)
      Date.parse(v) if v.present?
    rescue
      nil
    end

    def self.dump(v)
      v.to_s if v.present?
    end
  end
end
