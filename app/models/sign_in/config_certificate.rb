# frozen_string_literal: true

module SignIn
  class ConfigCertificate < ApplicationRecord
    self.table_name = 'sign_in_config_certificates'

    belongs_to :config, polymorphic: true
    belongs_to :cert, class_name: 'SignIn::Certificate', foreign_key: :certificate_id, inverse_of: :config_certificates
    accepts_nested_attributes_for :cert
    validates_associated :cert

    def cert_attributes=(attrs)
      attrs = attrs.to_h.symbolize_keys
      pem = attrs[:pem]

      if pem.present?
        existing_cert = SignIn::Certificate.find_by(pem:)
        if existing_cert
          self.cert = existing_cert
          return
        end
      end

      super
    end
  end
end
