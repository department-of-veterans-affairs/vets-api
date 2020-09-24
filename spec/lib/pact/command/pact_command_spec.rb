# frozen_string_literal: true

require 'rails_helper'
require 'commands/pact/pact_command'

describe Pact::Command::PactCommand do
  context 'when the new command is called' do
    it 'calls the pact generator perform method' do
      expect(ProviderStateGenerator).to receive(:start)
      subject.perform('new', ['test'])
    end

    context 'when the new command is missing' do
      it 'calls Rails::Command.invoke' do
        expect(Rails::Command).to receive(:invoke)
        subject.perform
      end
    end
  end
end
