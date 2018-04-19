require 'sinatra/base'
require 'support/mock_saml/idp_service'

module MockSaml
  class Idp < Sinatra::Base
    get '/saml/metadata/provider' do
      idp_service = MockSaml::IdpService.new
      content_type 'text/xml'
      idp_service.metadata
    end


  end
end
