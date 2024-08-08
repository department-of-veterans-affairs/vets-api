# frozen_string_literal: true

require 'rails_helper'

describe FacilitiesApi::V2::Lighthouse::Service, team: :facilities, type: :model do
  context 'Creating' do
    let(:attributes) do
      {
        'serviceInfo' => {
          'name' => 'Audiology and speech',
          'serviceId' => 'audiology',
          'serviceType' => 'health'
        },
        'waitTime' => {
          'new' => 0.2,
          'established' => 0.4,
          'effectiveDate' => '12-12-1222'
        }
      }
    end

    it 'has object defaults' do
      service = FacilitiesApi::V2::Lighthouse::Service.new(attributes)
      expect(service.attributes).to match(
        {
          serviceName: 'Audiology and speech',
          service: 'audiology',
          serviceType: 'health',
          new: 0.2,
          established: 0.4,
          effectiveDate: '12-12-1222'
        }
      )
    end
  end
end
