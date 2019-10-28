# frozen_string_literal: true

require 'rails_helper'
require 'commands/va/va_command'

describe Va::Command::VaCommand do
  context 'when the new command is called' do
    it 'calls the module generator perform method' do
      expect(ModuleGenerator).to receive(:start)
      subject.perform('new', ['foo'])
    end

    context 'when the new command is missing' do
      it 'calls Rails::Command.invoke' do
        expect(Rails::Command).to receive(:invoke)
        subject.perform
      end
    end
  end
end
