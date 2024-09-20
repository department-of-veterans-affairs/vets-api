# frozen_string_literal: true

module MHV
  module UserAccount
    module Errors
      class UserAccountError < StandardError; end
      class CreatorError < UserAccountError; end
      class ValidationError < UserAccountError; end
      class MHVClientError < UserAccountError; end
    end
  end
end
