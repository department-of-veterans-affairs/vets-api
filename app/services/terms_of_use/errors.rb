# frozen_string_literal: true

module TermsOfUse
  module Errors
    class ProvisionerError < StandardError; end
    class AcceptorError < StandardError; end
    class DeclinerError < StandardError; end
  end
end
