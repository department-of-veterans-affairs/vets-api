# frozen_string_literal: true
class SamlController < ApplicationController
  skip_before_action :authenticate, only: [:metadata]

  def metadata
    meta = OneLogin::RubySaml::Metadata.new
    saml_settings
    render xml: meta.generate(saml_settings), content_type: 'application/xml'
  end
end
