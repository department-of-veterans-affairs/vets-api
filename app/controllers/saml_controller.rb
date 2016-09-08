# frozen_string_literal: true
class SamlController < ApplicationController
  skip_before_action :authenticate, only: [:metadata]

  def metadata
    meta = OneLogin::RubySaml::Metadata.new
    render xml: meta.generate(SAML::SETTINGS), content_type: 'application/xml'
  end
end
