# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mobile::V0::LighthouseParamsFactory, type: :model do
  describe '#params' do
    context 'with an iam user' do
      let(:user) { FactoryBot.build(:iam_user) }
      let(:factory) { Mobile::V0::LighthouseParamsFactory.new(user.icn) }

      before do
        allow_any_instance_of(Mobile::V0::LighthouseAssertion).to receive(:token).and_return('abc123')
      end

      it 'generates the URI form encoded params needed to establish a lighthouse session' do
        expect(URI.decode_www_form(factory.build)).to eq(
          [
            %w[grant_type client_credentials],
            ['client_assertion_type', 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'],
            %w[client_assertion abc123],
            ['scope', 'launch launch/patient patient/Immunization.read patient/Location.read'],
            ['launch', 'eyJwYXRpZW50IjoiMTAwODU5NjM3OVY4NTk4MzgifQ==']
          ]
        )
      end
    end
  end
end
