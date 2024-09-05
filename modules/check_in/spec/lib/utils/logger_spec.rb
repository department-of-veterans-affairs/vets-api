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
    context 'when endpoint called without facility_type' do
      let(:controller) do
        double('FooController',
               controller_name: 'sessions',
               action_name: 'show',
               response: { body: '' },
               params: { id: '123' },
               permitted_params: {})
      end
      let(:resp) do
        {
          workflow: 'Min-Auth',
          uuid: '123',
          controller: 'sessions',
          action: 'show',
          initiated_by: '',
          facility_type: nil,
          filter: :before_action
        }
      end

      it 'returns the before info hash with nil facility_type' do
        expect(described_class.build(controller).before).to eq(resp)
      end
    end

    context 'when endpoint called with facility_type' do
      let(:controller) do
        double('FooController',
               controller_name: 'sessions',
               action_name: 'show',
               response: { body: '' },
               params: { id: '123', facility_type: 'oh' },
               permitted_params: {})
      end
      let(:resp) do
        {
          workflow: 'Min-Auth',
          uuid: '123',
          controller: 'sessions',
          action: 'show',
          initiated_by: '',
          facility_type: 'oh',
          filter: :before_action
        }
      end

      it 'returns the before info hash with nil facility_type' do
        expect(described_class.build(controller).before).to eq(resp)
      end
    end
  end

  describe '#after' do
    context 'when patient_check_ins#show' do
      let(:resp) do
        {
          workflow: 'Day-Of-Check-In',
          uuid: '123',
          controller: 'patient_check_ins',
          action: 'show',
          api_status: 'success 200',
          filter: :after_action
        }
      end

      context 'when set_e_checkin_started_called = false without facility_type' do
        let(:controller) do
          double('FooController',
                 controller_name: 'patient_check_ins',
                 action_name: 'show',
                 response: double('ResponseBody', body: '{"a":"b", "status":"success 200", "c":"d"}'),
                 params: { id: '123', set_e_checkin_started_called: false },
                 permitted_params: { uuid: '345' })
        end
        let(:resp_with_initiated_by_vetext) do
          resp.merge(initiated_by: 'vetext', facility_type: nil)
        end

        it 'returns the after info hash with initiated_by set with vetext' do
          expect(described_class.build(controller).after).to eq(resp_with_initiated_by_vetext)
        end
      end

      context 'when set_e_checkin_started_called = true without facility_type' do
        let(:controller) do
          double('FooController',
                 controller_name: 'patient_check_ins',
                 action_name: 'show',
                 response: double('ResponseBody', body: '{"a":"b", "status":"success 200", "c":"d"}'),
                 params: { id: '123', set_e_checkin_started_called: true },
                 permitted_params: { uuid: '123' })
        end
        let(:resp_with_initiated_by_veteran) do
          resp.merge(initiated_by: 'veteran', facility_type: nil)
        end

        it 'returns the after info hash with initiated_by set with vetext' do
          expect(described_class.build(controller).after).to eq(resp_with_initiated_by_veteran)
        end
      end

      context 'when set_e_checkin_started_called = true with oh facility_type' do
        let(:controller) do
          double('FooController',
                 controller_name: 'patient_check_ins',
                 action_name: 'show',
                 response: double('ResponseBody', body: '{"a":"b", "status":"success 200", "c":"d"}'),
                 params: { id: '123', set_e_checkin_started_called: true, facility_type: 'oh' },
                 permitted_params: { uuid: '123' })
        end
        let(:resp_with_initiated_by_veteran) do
          resp.merge(initiated_by: 'veteran', facility_type: 'oh')
        end

        it 'returns the after info hash with initiated_by set with vetext' do
          expect(described_class.build(controller).after).to eq(resp_with_initiated_by_veteran)
        end
      end
    end

    context 'when patient_check_ins#create' do
      let(:resp) do
        {
          workflow: 'Day-Of-Check-In',
          uuid: '123',
          controller: 'patient_check_ins',
          action: 'create',
          api_status: 'success 200',
          facility_type: nil,
          filter: :after_action
        }
      end

      context 'when set_e_checkin_started_called = false' do
        let(:controller) do
          double('FooController',
                 controller_name: 'patient_check_ins',
                 action_name: 'create',
                 response: double('ResponseBody', body: '{"a":"b", "status":"success 200", "c":"d"}'),
                 params: { patient_check_ins: { id: '123', set_e_checkin_started_called: false } },
                 permitted_params: { uuid: '123' })
        end
        let(:resp_with_initiated_by_vetext) do
          resp.merge(initiated_by: 'vetext')
        end

        it 'returns the after info hash with initiated_by set with vetext' do
          expect(described_class.build(controller).after).to eq(resp_with_initiated_by_vetext)
        end
      end

      context 'when set_e_checkin_started_called = true' do
        let(:controller) do
          double('FooController',
                 controller_name: 'patient_check_ins',
                 action_name: 'create',
                 response: double('ResponseBody', body: '{"a":"b", "status":"success 200", "c":"d"}'),
                 params: { patient_check_ins: { id: '123', set_e_checkin_started_called: true } },
                 permitted_params: { uuid: '123' })
        end
        let(:resp_with_initiated_by_veteran) do
          resp.merge(initiated_by: 'veteran')
        end

        it 'returns the after info hash with initiated_by set with veteran' do
          expect(described_class.build(controller).after).to eq(resp_with_initiated_by_veteran)
        end
      end
    end
  end
end
