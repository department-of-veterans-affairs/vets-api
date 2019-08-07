# frozen_string_literal: true

class SamlController < ApplicationController
  skip_before_action :authenticate, only: [:metadata, :metadata_v2]

  def metadata
    meta = OneLogin::RubySaml::Metadata.new
    render xml: meta.generate(SAML::SettingsService.saml_settings), content_type: 'application/xml'
  end

  def metadata_v2
    meta = OneLogin::RubySaml::Metadata.new
    render xml: meta.generate(SAML::SettingsServiceV2.saml_settings), content_type: 'application/xml'
  end
end
