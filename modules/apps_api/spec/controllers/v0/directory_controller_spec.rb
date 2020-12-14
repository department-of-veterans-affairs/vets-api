# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::DirectoryController, type: :controller do
  include RequestHelper

  describe '#index' do
    it 'returns a response' do
      get :index
      expect(response).to be_successful
    end
  end

  describe '#create' do
    it 'creates a Directory Application' do
      expect(DirectoryApplication).to receive(:create)
    end
  end

  describe '#show' do
    it 'returns iBlueButton when passed the correct id' do
      get(:show, {'id' => 'iBlueButton'})
      json = json_body_for(response)
      expect(response).to be_successful
      expect(json['data']['name']).to eql?('iBlueButton')
    end
  end
end
