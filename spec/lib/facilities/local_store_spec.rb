# frozen_string_literal: true
require 'rails_helper'
require 'facilities/local_store'

RSpec.describe Facilities::LocalStore do
  let(:url) { 'https://www.example.com/VBA_Facilities' }
  let(:service_error) { Facilities::Errors::ServiceError.new('GIS Error') }
  let(:adapter_stub) { class_double('VBAFacilityAdapter') }
  subject { described_class.new(url, nil, adapter_stub) }

  describe '#check_for_freshness' do
    context 'bulk client raises service error' do
      it 'should log error' do
        allow_any_instance_of(Facilities::BulkClient).to receive(:last_edit_date).and_return(1_234_567_890)
        allow_any_instance_of(Facilities::BulkClient).to receive(:fetch_all).and_raise(service_error)
        expect(Rails.logger).to receive(:error)
        subject.get('314c')
      end
    end

    context 'bulk client raises standard error' do
      it 'should log error' do
        allow_any_instance_of(Facilities::BulkClient).to receive(:last_edit_date).and_return(1_234_567_890)
        allow_any_instance_of(Facilities::BulkClient).to receive(:fetch_all).and_raise(StandardError.new('GIS Error'))
        expect(Rails.logger).to receive(:error)
        subject.get('314c')
      end
    end
  end
end
