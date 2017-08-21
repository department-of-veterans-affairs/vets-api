# frozen_string_literal: true
module AuthenticatedSessionHelper
  def use_authenticated_current_user(options = {})
    current_user = options[:current_user] || build(:user)

    expect_any_instance_of(ApplicationController)
      .to receive(:authenticate_token).at_least(:once).and_return(:true)
    expect_any_instance_of(ApplicationController)
      .to receive(:current_user).at_least(:once).and_return(current_user)
  end

  def use_authenticated_saml_user(saml_response_xml)
    decoded_response = Base64.decode64(saml_response_xml)
    user_uuid = Ox.parse(decoded_response).ID

    saml_response = OneLogin::RubySaml::Response.new(
      saml_response_xml, settings: saml_settings
    )

    current_user = User.from_saml(saml_response)
    session = Session.new(uuid: current_user.uuid)
    session.save && current_user.save
    session
  end

  def saml_settings
    saml_settings_cassette { SAML::SettingsService.saml_settings }
  end

  def saml_settings_cassette
    VCR.use_cassette('development_cassettes/saml_settings') do
      yield if block_given
    end
  end
end
