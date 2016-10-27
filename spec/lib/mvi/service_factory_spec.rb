# frozen_string_literal: true
require 'mvi/service_factory'

describe MVI::ServiceFactory do
  context 'when used without an env var' do
    context 'when mock_service is false' do
      it 'should return the real service' do
        expect(MVI::ServiceFactory.get_service(mock_service: false)).to be_an_instance_of(MVI::Service)
      end
    end
    context 'when mock_service is true' do
      it 'should return the mock service' do
        expect(MVI::ServiceFactory.get_service(mock_service: true)).to be_an_instance_of(MVI::MockService)
      end
    end
  end
  context 'when used with an env var' do
    context 'when MOCK_MVI_SERVICE is false' do
      it 'should return the real service' do
        ClimateControl.modify MOCK_MVI_SERVICE: 'false' do
          expect(MVI::ServiceFactory.get_service(mock_service: ENV['MOCK_MVI_SERVICE'])).to be_an_instance_of(MVI::Service)
        end
      end
    end
    context 'when MOCK_MVI_SERVICE is nil' do
      it 'should return the real service' do
        ClimateControl.modify MOCK_MVI_SERVICE: nil do
          expect(MVI::ServiceFactory.get_service).to be_an_instance_of(MVI::Service)
        end
      end
    end
    context 'when MOCK_MVI_SERVICE is true' do
      it 'should return the mock service' do
        ClimateControl.modify MOCK_MVI_SERVICE: 'true' do
          expect(MVI::ServiceFactory.get_service(mock_service: ENV['MOCK_MVI_SERVICE'])).to be_an_instance_of(MVI::MockService)
        end
      end
    end
  end
end
