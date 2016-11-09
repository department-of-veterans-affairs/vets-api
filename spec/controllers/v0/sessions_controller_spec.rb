# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::SessionsController, type: :controller do
  let(:mvi_user) { FactoryGirl.build(:mvi_user) }
  let(:saml_attrs) do
    {
      'uuid' => [mvi_user.uuid],
      'email' => [mvi_user.email],
      'fname' => [mvi_user.first_name],
      'lname' => [mvi_user.last_name],
      'mname' => [''],
      'social' => [mvi_user.ssn],
      'gender' => ['male'],
      'birth_date' => [mvi_user.birth_date.strftime('%Y-%m-%d')],
      'level_of_assurance' => [mvi_user.loa[:highest]]
    }
  end
  let(:settings_no_context) { FactoryGirl.build(:settings_no_context) }
  let(:loa1_xml) { File.read("#{::Rails.root}/spec/fixtures/files/saml_xml/loa1_response.xml") }
  let(:loa3_xml) { File.read("#{::Rails.root}/spec/fixtures/files/saml_xml/loa3_response.xml") }
  let(:settings_service) { class_double(SAML::SettingsService).as_stubbed_const }
  let(:fake_relay) { '/some/resource' }
  let(:query_token) { Rack::Utils.parse_query(URI.parse(response.location).query)['token'] }

  before(:each) do
    stub_request(:get, SAML_CONFIG['metadata_url']).to_return(body: 'abc')
    allow_any_instance_of(Decorators::MviUserDecorator).to receive(:create).and_return(mvi_user)
    allow_any_instance_of(SAML::SettingsService).to receive(:saml_settings).and_return(settings_no_context)
  end

  context 'when not logged in' do
    context 'when browser contains an invalid authorization token' do
      let(:invalid_token) { 'iam-aninvalid-tokenvalue' }
      let(:auth_header) { ActionController::HttpAuthentication::Token.encode_credentials(invalid_token) }

      it 'GET show - returns unauthorized' do
        request.env['HTTP_AUTHORIZATION'] = auth_header
        delete :destroy
        expect(response).to have_http_status(:unauthorized)
      end
    end
    it 'GET new - shows the ID.me authentication url' do
      allow_any_instance_of(OneLogin::RubySaml::Authrequest)
        .to receive(:create).and_return('url_string')
      get :new
      expect(JSON.parse(response.body)).to eq('authenticate_via_get' => 'url_string')
    end

    it 'GET new - with LOA 1 supplied, the saml authn request will use LOA 1' do
      get :new, level: 1

      response_body = JSON.parse(response.body)
      authn_request = SAML::AuthnRequestHelper.new(response_body['authenticate_via_get'])
      expect(authn_request.loa1?).to eq(true)
    end
    it 'GET new - with LOA 3 supplied, the saml authn request will use LOA 3' do
      get :new, level: 3

      response_body = JSON.parse(response.body)
      authn_request = SAML::AuthnRequestHelper.new(response_body['authenticate_via_get'])
      expect(authn_request.loa3?).to eq(true)
    end

    it 'GET new - no level supplied, the saml authn request will use LOA 1' do
      get :new

      response_body = JSON.parse(response.body)
      authn_request = SAML::AuthnRequestHelper.new(response_body['authenticate_via_get'])
      expect(authn_request.loa1?).to eq(true)
    end

    it 'GET new - with an invalid level supplied, we default to LOA 1' do
      get :new, level: 'bad_level!!'

      response_body = JSON.parse(response.body)
      authn_request = SAML::AuthnRequestHelper.new(response_body['authenticate_via_get'])
      expect(authn_request.loa1?).to eq(true)
    end

    it 'DELETE destroy - returns returns unauthorized' do
      delete :destroy
      expect(response).to have_http_status(:unauthorized)
    end

    context 'GET saml_callback ' do
      let(:token) { 'abracadabra-open-sesame' }
      let(:loa1_user) { build :loa1_user }
      let(:loa3_user) { build :loa3_user }
      let(:loa3_saml_attrs) do
        {
          'uuid' => [loa3_user.uuid],
          'email' => [loa3_user.email],
          'fname' => [loa3_user.first_name],
          'lname' => [loa3_user.last_name],
          'mname' => [''],
          'social' => [loa3_user.ssn],
          'gender' => ['male'],
          'birth_date' => [loa3_user.birth_date.strftime('%Y-%m-%d')],
          'level_of_assurance' => [loa3_user.loa[:highest]]
        }
      end
      let(:attributes) { double('attributes') }
      let(:saml_response) { double('saml_response', is_valid?: true, attributes: attributes) }

      before(:example) do
        allow(attributes).to receive_message_chain(:all, :to_h).and_return(saml_attrs)
        allow(OneLogin::RubySaml::Response).to receive(:new).and_return(saml_response)
        allow(saml_response).to receive(:decrypted_document).and_return(REXML::Document.new(loa3_xml))
      end

      it 'should uplevel an LOA 1 session to LOA 3' do
        allow(attributes).to receive_message_chain(:all, :to_h).and_return(loa3_saml_attrs)
        allow_any_instance_of(Decorators::MviUserDecorator).to receive(:create).and_return(loa3_user)

        Session.create(uuid: loa1_user.uuid, token: token)
        User.create(loa1_user)

        post :saml_callback, RelayState: fake_relay
        assert_response :found

        user = User.find(loa1_user.uuid)
        expect(user.attributes).to eq(loa3_user.attributes)
      end

      it 'returns a valid session and user' do
        post :saml_callback

        token = Rack::Utils.parse_query(URI.parse(response.location).query)['token']
        session = Session.find(token)
        expect(session).to_not be_nil
        expect(User.find(session.uuid).attributes).to eq(mvi_user.attributes)
      end

      it 'creates a job to create an evss user when user has loa3 and evss attrs' do
        expect { get :saml_callback }.to change(EVSS::CreateUserAccountJob.jobs, :size).by(1)
      end

      it 'does not create a job to create an evss user when user has loa1' do
        allow(saml_response).to receive(:decrypted_document).and_return(REXML::Document.new(loa1_xml))
        expect { get :saml_callback }.to_not change(EVSS::CreateUserAccountJob.jobs, :size)
      end

      it 'parses and stores the current level of assurance' do
        post :saml_callback, RelayState: fake_relay
        assert_response :found

        session = Session.find(query_token)
        user = User.find(session.uuid)
        expect(user.loa[:current]).to eq(LOA::TWO)
      end

      it 'parses and stores the highest level of assurance proofing' do
        post :saml_callback, RelayState: fake_relay
        assert_response :found

        session = Session.find(query_token)
        user = User.find(session.uuid)
        expect(user.loa[:highest]).to eq(LOA::THREE)
      end
    end

    it 'GET saml_callback - responds with a redirect to an auth failure page' do
      errors = ['Response is invalid']
      allow(OneLogin::RubySaml::Response)
        .to receive(:new).and_return(double('saml_response', is_valid?: false, errors: errors))

      expect(post(:saml_callback)).to redirect_to(SAML_CONFIG['relay'] + '?auth=fail')
      expect(response).to have_http_status(:found)
    end
  end

  context 'when logged in' do
    let(:token) { 'abracadabra-open-sesame' }
    let(:auth_header) { ActionController::HttpAuthentication::Token.encode_credentials(token) }
    let(:test_user) { FactoryGirl.build(:user) }

    before(:each) do
      Session.create(uuid: test_user.uuid, token: token)
      User.create(test_user)
    end

    it 'destroys a session' do
      request.env['HTTP_AUTHORIZATION'] = auth_header
      delete :destroy
      expect(response).to have_http_status(202)
    end
  end
end
