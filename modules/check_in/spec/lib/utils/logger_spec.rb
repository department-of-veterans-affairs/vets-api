# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIn::Utils::Logger do
  subject { described_class }

  describe '.build' do
    it 'is a type of CheckIn::Utils::Logger' do
      expect(described_class.build(nil)).to be_a(CheckIn::Utils::Logger)
    end
  end

  describe '#before' do
    let(:controller) do
      double('FooController',
             controller_name: 'sessions',
             action_name: 'show',
             response: { body: '' },
             params: { id: '123' },
             permitted_params: {})
    end
    let(:resp) { { workflow: 'Min-Auth', uuid: '123', controller: 'sessions', action: 'show', filter: :before_action } }

    it 'returns the before info hash' do
      expect(described_class.build(controller).before).to eq(resp)
    end
  end

  describe '#after' do
    let(:controller) do
      double('FooController',
             controller_name: 'patient_check_ins',
             action_name: 'create',
             response: double('ResponseBody', body: '{"a":"b", "status":"success 200", "c":"d"}'),
             params: { id: '123' },
             permitted_params: { uuid: '345' })
    end
    let(:resp) do
      {
        workflow: 'Day-Of-Check-In',
        uuid: '123',
        controller: 'patient_check_ins',
        action: 'create',
        api_status: 'success 200',
        filter: :after_action
      }
    end

    it 'returns the after info hash' do
      expect(described_class.build(controller).after).to eq(resp)
    end
  end
end
