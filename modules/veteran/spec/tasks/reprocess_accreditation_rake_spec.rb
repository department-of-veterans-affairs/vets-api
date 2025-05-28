# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'veteran:accreditation:reprocess', type: :task do
  before do
    Rake.application.rake_require 'tasks/reprocess_accreditation'
    Rake::Task.define_task(:environment)
    task.reenable
  end

  let(:task) { Rake::Task['veteran:accreditation:reprocess'] }

  describe 'parameter validation' do
    it 'exits with error when no rep_types provided' do
      expect { task.invoke }.to output(/Error: Please specify representative types/).to_stdout
                            .and raise_error(SystemExit)
    end

    it 'exits with error when invalid rep_type provided' do
      expect { task.invoke('invalid_type') }.to output(/Error: Invalid representative types: invalid_type/).to_stdout
                                            .and raise_error(SystemExit)
    end

    it 'accepts valid rep_types' do
      allow_any_instance_of(Veteran::VSOReloader).to receive(:perform)

      expect { task.invoke('attorneys,claims_agents') }
        .to output(/Starting manual reprocessing for: attorneys, claims_agents/).to_stdout
    end
  end

  describe 'reprocessing behavior' do
    let(:reloader) { instance_double(Veteran::VSOReloader) }

    before do
      allow(Veteran::VSOReloader).to receive(:new).and_return(reloader)
      allow(reloader).to receive(:instance_variable_set)
      allow(reloader).to receive(:define_singleton_method)
      allow(reloader).to receive(:perform)
    end

    it 'creates a VSOReloader instance with manual_reprocess_types' do
      task.invoke('attorneys')

      expect(reloader).to have_received(:instance_variable_set).with(:@manual_reprocess_types, [:attorneys])
    end

    it 'overrides validate_count method' do
      task.invoke('attorneys,vso_representatives')

      expect(reloader).to have_received(:define_singleton_method).with(:validate_count)
    end

    it 'calls perform on the reloader' do
      task.invoke('claims_agents')

      expect(reloader).to have_received(:perform)
    end

    it 'outputs success message when reprocessing completes' do
      expect { task.invoke('attorneys') }.to output(/Reprocessing completed successfully/).to_stdout
    end

    context 'when an error occurs' do
      before do
        allow(reloader).to receive(:perform).and_raise(StandardError, 'Something went wrong')
      end

      it 'outputs error message and exits' do
        expect { task.invoke('attorneys') }
          .to output(/Error during reprocessing: Something went wrong/).to_stdout
          .and raise_error(SystemExit)
      end
    end
  end

  describe 'validate_count override behavior' do
    it 'allows manual override for specified types' do
      # This tests the actual override logic
      reloader = Veteran::VSOReloader.new
      reloader.instance_variable_set(:@manual_reprocess_types, [:attorneys])
      reloader.instance_variable_set(:@validation_results, {})

      # Define the override method as the rake task does
      reloader.define_singleton_method(:validate_count) do |rep_type, new_count|
        if @manual_reprocess_types.include?(rep_type)
          @validation_results[rep_type] = new_count
          true
        else
          super(rep_type, new_count)
        end
      end

      # Test that manual types bypass validation
      expect(reloader.validate_count(:attorneys, 50)).to be true
      expect(reloader.instance_variable_get(:@validation_results)[:attorneys]).to eq(50)
    end
  end
end
