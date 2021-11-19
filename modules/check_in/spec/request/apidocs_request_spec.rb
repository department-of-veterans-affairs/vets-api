# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Apidocs', type: :request do
  describe 'V0 GET `index`' do
    it 'is a Hash' do
      get '/check_in/v0/apidocs'

      expect(JSON.parse(response.body)).to be_a(Hash)
    end

    it 'is the check-in swagger' do
      get '/check_in/v0/apidocs'

      info_hsh = {
        'version' => '0.0.1',
        'title' => 'Check-in',
        'description' => "## The API for the Check-in module\n",
        'contact' => {
          'name' => 'va.gov'
        }
      }
      swagger = JSON.parse(response.body)

      expect(swagger['info']).to eq(info_hsh)
    end
  end

  describe 'V2 GET `index`' do
    it 'is a Hash' do
      get '/check_in/v2/apidocs'

      expect(JSON.parse(response.body)).to be_a(Hash)
    end

    it 'is the check-in swagger' do
      get '/check_in/v2/apidocs'

      info_hsh = {
        'version' => '0.0.2',
        'title' => 'Check-in',
        'description' => "## The API for the Check-in module\n",
        'contact' => {
          'name' => 'va.gov'
        }
      }
      swagger = JSON.parse(response.body)

      expect(swagger['info']).to eq(info_hsh)
    end
  end
end
