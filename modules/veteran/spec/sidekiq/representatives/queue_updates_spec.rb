# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe Representatives::QueueUpdates, type: :job do
  describe 'modules and initialization' do
    it 'includes Sidekiq::Job' do
      expect(described_class.included_modules).to include(Sidekiq::Job)
    end
  end

  describe '#perform' do
    let(:file_content) { 'dummy file content' }
    let(:raw_address123) do
      {
        'address_line1' => '123 Test St',
        'address_line2' => nil,
        'address_line3' => nil,
        'city' => 'Test City',
        'state_code' => 'NY',
        'zip_code5' => '12345',
        'zip_code4' => nil
      }
    end
    let(:processed_data) do
      {
        'Agents' => [{ id: '123', address: {}, phone_number: '123-456-7890', raw_address: raw_address123 }],
        'Attorneys' => [{ id: '234', address: {}, phone_number: '123-456-7890', raw_address: {} }],
        'Representatives' => [{ id: '345', address: {}, phone_number: '123-456-7890', raw_address: {} }]
      }
    end
    let(:batch) { instance_double(Sidekiq::Batch) }
    let(:temp_file) { Tempfile.new(['test', '.xlsx']) }

    before do
      stub_const('Sidekiq::Batch', Class.new) unless defined?(Sidekiq::Batch)
      Veteran::Service::Representative.create(representative_id: '123', poa_codes: ['A1'])
      Veteran::Service::Representative.create(representative_id: '234', poa_codes: ['A1'])
      Veteran::Service::Representative.create(representative_id: '345', poa_codes: ['A1'])
      temp_file.binmode
      temp_file.write(file_content)
      temp_file.close
      allow(RepresentationManagement::GCLAWS::XlsxClient)
        .to receive(:download_accreditation_xlsx)
        .and_yield({ success: true, file_path: temp_file.path })
      allow_any_instance_of(Representatives::XlsxFileProcessor).to receive(:process).and_return(processed_data)
      allow(Sidekiq::Batch).to receive(:new).and_return(batch)
      allow(batch).to receive(:description=)
      allow(batch).to receive(:jobs).and_yield
    end

    after { temp_file.unlink }

    context 'when file processing is successful' do
      it 'processes the file and queues updates' do
        expect { subject.perform }.not_to raise_error

        expected_jobs_count = processed_data.keys.size
        expect(Representatives::Update.jobs.size).to eq(expected_jobs_count)
      end

      it 'updates raw_address for records with changed raw_address' do
        rep = Veteran::Service::Representative.find('123')
        expect(rep.raw_address).to be_nil

        subject.perform
        rep.reload

        expect(rep.raw_address).to eq(raw_address123)
      end

      it 'does not update raw_address when it matches existing value' do
        rep = Veteran::Service::Representative.find('123')
        rep.update(raw_address: raw_address123)
        initial_updated_at = rep.updated_at

        subject.perform
        rep.reload

        expect(rep.raw_address).to eq(raw_address123)
        expect(rep.updated_at).to eq(initial_updated_at)
      end
    end

    context 'when GCLAWS download fails' do
      before do
        allow(RepresentationManagement::GCLAWS::XlsxClient)
          .to receive(:download_accreditation_xlsx)
          .and_yield({ success: false, error: 'timeout', status: :request_timeout })
      end

      it 'does not process the file or queue updates' do
        expect { subject.perform }.not_to raise_error
        expect(Representatives::Update.jobs).to be_empty
      end
    end

    context 'when an exception is raised' do
      before do
        allow_any_instance_of(Representatives::XlsxFileProcessor).to receive(:process).and_raise(StandardError,
                                                                                                 'test error')
        allow_any_instance_of(described_class).to receive(:log_error)
      end

      it 'logs the error' do
        expect { subject.perform }.not_to raise_error
        expect(subject).to have_received(:log_error).with('Error in file fetching process: test error') # rubocop:disable RSpec/SubjectStub
      end
    end
  end
end
