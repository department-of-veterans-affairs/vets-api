# frozen_string_literal: true

require 'common/models/base'

class MessagingSignature < Common::Base
  include ActiveModel::Validations

  attribute :signature_name, String
  attribute :signature_title, String
  attribute :include_signature, Boolean

  validates :signature_name, :signature_title, :include_signature, presence: true
end
