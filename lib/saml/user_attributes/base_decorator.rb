# frozen_string_literal: true
module SAML
  module UserAttributes
    class BaseDecorator < SimpleDelegator
      def initialize(saml_user)
        super(saml_user)
      end

      # Implement try on instances of BasicObject which is what decorator is
      def try(*a, &b)
        if a.empty? && block_given?
          yield self
        else
          __send__(*a, &b)
        end
      end
    end
  end
end
