# frozen_string_literal: true

require 'rails_helper'
require 'generators/provider_state/provider_state_generator'

describe ProviderStateGenerator do
  describe 'create_provider_state_file' do
    after do
      test_pact_file = 'spec/service_consumers/provider_states_for/test.rb'
      FileUtils.rm_rf(test_pact_file) if File.exist?(test_pact_file)
    end

    it 'creates the pact provider state file for a given consumer' do
      expect do
        ProviderStateGenerator.new(['test']).create_provider_state_file
      end.to output("      create  spec/service_consumers/provider_states_for/test.rb\n").to_stdout
      expect(File).to exist('spec/service_consumers/provider_states_for/test.rb')
    end
  end
end
