module SAML
  module UserAttributes
    class BaseDecorator < SimpleDelegator
      def initialize(saml_user)
        super(saml_user)
      end
    end
  end
end
