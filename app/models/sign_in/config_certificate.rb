# frozen_string_literal: true

module SignIn
  class ConfigCertificate < ApplicationRecord
    self.table_name = 'sign_in_config_certificates'

    belongs_to :config, polymorphic: true
    belongs_to :cert, class_name: 'SignIn::Certificate', foreign_key: :certificate_id, inverse_of: :config_certificates
  end
end
