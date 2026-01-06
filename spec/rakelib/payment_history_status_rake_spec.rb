# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'payment_history:debug_empty rake task' do
  before(:all) do
    Rake.application.rake_require '../rakelib/payment_history_status'
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task['payment_history:debug_empty'] }
  let(:icn) { '1234567890V123456' }

  before do
    task.reenable
  end

  describe 'payment_history:debug_empty' do
    context 'when no ICN is provided' do
      it 'displays usage message and exits' do
        expect { task.invoke }.to raise_error(SystemExit).and output(/Usage:/).to_stdout
      end
    end

    context 'when ICN is provided' do
      context 'and feature flag is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(true)
        end

        it 'shows feature flag is enabled' do
          expect { task.invoke(icn) }.to output(/payment_history is ENABLED/).to_stdout
        end

        it 'masks the ICN in output' do
          expect { task.invoke(icn) }.to output(/1234\*/).to_stdout
        end
      end

      context 'and feature flag is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(false)
        end

        it 'shows feature flag is disabled' do
          expect { task.invoke(icn) }.to output(/payment_history is DISABLED/).to_stdout
        end

        it 'provides instructions to enable' do
          expect { task.invoke(icn) }.to output(/Flipper.enable/).to_stdout
        end
      end
    end
  end
end
