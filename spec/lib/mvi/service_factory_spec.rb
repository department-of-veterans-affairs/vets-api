# frozen_string_literal: true
require 'mvi/service_factory'

describe MVI::ServiceFactory do
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

  context 'when Settings.mvi.mock is nil' do
    it 'should return the real service' do
      expect(MVI::ServiceFactory.get_service).to be_an_instance_of(MVI::Service)
    end
  end
end
