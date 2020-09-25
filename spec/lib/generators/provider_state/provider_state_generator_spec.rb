# frozen_string_literal: true

require 'rails_helper'
require 'generators/provider_state/provider_state_generator'

describe ProviderStateGenerator do
  describe 'create_provider_state_file' do
    context 'once generated' do
      before(:all) { ProviderStateGenerator.new(['test']).create_provider_state_file }

      after(:all) { FileUtils.rm_rf('spec/service_consumers/provider_states_for/test.rb') }

      it 'creates the pact provider state file for a given consumer' do
        expect(File).to exist('spec/service_consumers/provider_states_for/test.rb')
      end
    end
  end
end
