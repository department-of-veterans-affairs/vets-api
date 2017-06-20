# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Facilities::AccessDataDownload, type: :job do
  let(:satisfaction_data) do
    fixture_file_name = "#{::Rails.root}/spec/fixtures/facility_access/satisfaction_data.json"
    File.open(fixture_file_name, 'rb') do |f|
      JSON.parse(f.read)
    end
  end

  let(:wait_time_data) do
    fixture_file_name = "#{::Rails.root}/spec/fixtures/facility_access/wait_time_data.json"
    File.open(fixture_file_name, 'rb') do |f|
      JSON.parse(f.read)
    end
  end

  it 'retrieves bulk access data' do
    VCR.use_cassette('facilities/access/all') do
      described_class.new.perform
    end
  end

  context 'with mock data' do
    let(:sat_client_stub) { instance_double('Facilities::AccessSatisfactionClient') }
    let(:wait_client_stub) { instance_double('Facilities::AccessWaitTimeClient') }

    before(:each) do
      allow(Facilities::AccessSatisfactionClient).to receive(:new) { sat_client_stub }
      allow(Facilities::AccessWaitTimeClient).to receive(:new) { wait_client_stub }
    end

    it 'populates data' do
      allow(sat_client_stub).to receive(:download).and_return(satisfaction_data)
      allow(wait_client_stub).to receive(:download).and_return(wait_time_data)

      described_class.new.perform
      expect(FacilitySatisfaction.find('438GD')).to_not be_nil
      expect(FacilityWaitTime.find('648GA')).to_not be_nil
    end

    it 'invalidates removed fields' do
      satisfaction_update = satisfaction_data.select { |x| x['facilityID'] != '438GD' }
      expect(sat_client_stub).to receive(:download).and_return(satisfaction_data)
      expect(sat_client_stub).to receive(:download).and_return(satisfaction_update)
      allow(wait_client_stub).to receive(:download).and_return(wait_time_data)

      described_class.new.perform
      expect(FacilitySatisfaction.find('438GD')).to_not be_nil

      described_class.new.perform
      expect(FacilitySatisfaction.find('438GD')).to be_nil
    end

    context 'handles satisfaction errors' do
      before do
        Settings.sentry.dsn = 'asdf'
      end
      after do
        Settings.sentry.dsn = nil
      end

      it 'bails on backend error' do
        expect(sat_client_stub).to receive(:download).and_raise(Common::Exceptions::BackendServiceException)
        expect(wait_client_stub).to receive(:download).and_return(wait_time_data)
        expect(Raven).to receive(:capture_exception).with(Common::Exceptions::BackendServiceException)

        described_class.new.perform
      end

      it 'bails on client error' do
        expect(sat_client_stub).to receive(:download).and_raise(Common::Client::Errors::ClientError)
        expect(wait_client_stub).to receive(:download).and_return(wait_time_data)
        expect(Raven).to receive(:capture_exception).with(Common::Client::Errors::ClientError)

        described_class.new.perform
      end

      it 'bails on missing expected key' do
        satisfaction_data[0].delete('facilityID')
        expect(sat_client_stub).to receive(:download).and_return(satisfaction_data)
        expect(wait_client_stub).to receive(:download).and_return(wait_time_data)
        expect(Raven).to receive(:capture_exception).with(Facilities::AccessDataError)

        described_class.new.perform
      end
    end

    context 'handles wait time errors' do
      before do
        Settings.sentry.dsn = 'asdf'
      end
      after do
        Settings.sentry.dsn = nil
      end

      it 'bails on backend error' do
        expect(sat_client_stub).to receive(:download).and_return(satisfaction_data)
        expect(wait_client_stub).to receive(:download).and_raise(Common::Exceptions::BackendServiceException)
        expect(Raven).to receive(:capture_exception).with(Common::Exceptions::BackendServiceException)

        described_class.new.perform
      end

      it 'bails on client error' do
        expect(sat_client_stub).to receive(:download).and_return(satisfaction_data)
        expect(wait_client_stub).to receive(:download).and_raise(Common::Client::Errors::ClientError)
        expect(Raven).to receive(:capture_exception).with(Common::Client::Errors::ClientError)

        described_class.new.perform
      end

      it 'bails on missing expected key' do
        wait_time_data[0].delete('facilityID')
        expect(sat_client_stub).to receive(:download).and_return(satisfaction_data)
        expect(wait_client_stub).to receive(:download).and_return(wait_time_data)
        expect(Raven).to receive(:capture_exception).with(Facilities::AccessDataError)

        described_class.new.perform
      end
    end
  end
end
