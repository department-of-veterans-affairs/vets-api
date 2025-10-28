# frozen_string_literal: true

require 'vets/model'

class MessagingSignature
  include Vets::Model

  attribute :signature_name, String
  attribute :signature_title, String
  attribute :include_signature, Bool, default: false

  validates :signature_name, :signature_title, :include_signature, presence: true

  def to_h
    {
      signatureName: signature_name,
      signatureTitle: signature_title,
      includeSignature: include_signature
    }
  end
end
