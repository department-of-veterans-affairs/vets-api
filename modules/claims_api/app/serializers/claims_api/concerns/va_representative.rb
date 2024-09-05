# frozen_string_literal: true

module ClaimsApi
  module Concerns
    module VARepresentative
      extend ActiveSupport::Concern

      included do
        attribute :va_representative do |object|
          ActionView::Base.full_sanitizer.sanitize(object.data['poa'])&.gsub(/&[^ ;]+;/, '')
        end
      end
    end
  end
end
