# frozen_string_literal: true

module Vye
  class UserInfo
    class DobSerializer
      def self.load(v)
        Date.parse(v) if v.present?
      end

      def self.dump(v)
        v.to_s if v.present?
      end
    end
  end
end
