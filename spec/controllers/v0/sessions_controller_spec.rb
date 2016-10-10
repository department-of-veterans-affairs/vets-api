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
      'birth_date' => [mvi_user.birth_date.strftime('%Y-%m-%d')]
    }
  end
  let(:rubysaml_settings) { FactoryGirl.build(:rubysaml_settings) }
  # has an LOA of 'authentication'
  let(:response_xml) { File.read("#{::Rails.root}/spec/fixtures/files/saml_response.xml") }
  before(:each) do
    allow_any_instance_of(Decorators::MviUserDecorator).to receive(:create).and_return(mvi_user)
    allow_any_instance_of(ApplicationController).to receive(:saml_settings).and_return(rubysaml_settings)
  end

  context 'when not logged in' do
    context 'when browser contains an invalid authorization token' do
      let(:invalid_token) { 'iam-aninvalid-tokenvalue' }
      let(:auth_header) { ActionController::HttpAuthentication::Token.encode_credentials(invalid_token) }

      it 'GET show - returns unauthorized' do
        request.env['HTTP_AUTHORIZATION'] = auth_header
        get :show
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it 'GET new - shows the ID.me authentication url' do
      allow_any_instance_of(OneLogin::RubySaml::Authrequest)
        .to receive(:create).and_return('url_string')
      get :new
      expect(JSON.parse(response.body)).to eq('authenticate_via_get' => 'url_string')
    end

    it 'GET show - returns unauthorized' do
      get :show
      expect(response).to have_http_status(:unauthorized)
    end

    it 'DELETE destroy - returns returns unauthorized' do
      delete :destroy
      expect(response).to have_http_status(:unauthorized)
    end

    context 'GET saml_callback ' do
      let(:attributes) { double('attributes') }
      let(:saml_response) { double('saml_response', is_valid?: true, attributes: attributes) }

      before(:example) do
        allow(attributes).to receive_message_chain(:all, :to_h).and_return(saml_attrs)
        allow(OneLogin::RubySaml::Response).to receive(:new).and_return(saml_response)
        allow(saml_response).to receive(:response).and_return(response_xml)
      end

      it 'returns a valid token session' do
        get :saml_callback

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body).keys).to include('token', 'uuid')
      end

      it 'creates a valid session' do
        get :saml_callback

        token = JSON.parse(response.body)['token']
        expect(Session.find(token)).not_to be_nil
      end

      it 'stores the user' do
        get :saml_callback

        uuid = JSON.parse(response.body)['uuid']
        user = User.find(uuid)
        expect(user).not_to be_nil
        expect(user.first_name).to eq(saml_attrs['fname'].first)
      end

      it 'parses and stores level of assurance' do
        get :saml_callback

        uuid = JSON.parse(response.body)['uuid']
        user = User.find(uuid)
        expect(user.level_of_assurance).to eq(LOA::ONE)
      end
    end

    it 'GET saml_callback - returns unauthorized from an invalid SAML response' do
      errors = ['Response is invalid']
      allow(OneLogin::RubySaml::Response)
        .to receive(:new).and_return(double('saml_response', is_valid?: false, errors: errors))

      get :saml_callback
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['errors']).to eq(['Response is invalid'])
    end
  end

  context 'when logged in' do
    let(:token) { 'abracadabra-open-sesame' }
    let(:auth_header) { ActionController::HttpAuthentication::Token.encode_credentials(token) }

    before(:each) do
      Session.create(uuid: '1234', token: token)
      User.create(
        uuid: '1234',
        email: 'test@test.com',
        first_name: 'abraham',
        last_name: 'lincoln',
        birth_date: Time.new(1809, 2, 12).utc,
        ssn: '111223333'
      )
    end

    it 'returns a JSON the session' do
      request.env['HTTP_AUTHORIZATION'] = auth_header
      get :show
      assert_response :success

      json = JSON.parse(response.body)

      expect(json['uuid']).to eq('1234')
      expect(json['token']).to eq(token)
    end

    it 'destroys a session' do
      request.env['HTTP_AUTHORIZATION'] = auth_header
      expect_any_instance_of(Session).to receive(:destroy)
      delete :destroy
      expect(response).to have_http_status(:no_content)
    end
  end
end
