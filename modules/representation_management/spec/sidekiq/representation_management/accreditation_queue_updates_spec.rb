# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::AccreditationQueueUpdates do
  let(:fixture_path) { 'modules/representation_management/spec/fixtures/xlsx_files/rep-mock-data.xlsx' }
  let(:fixture_file_content) { File.read(fixture_path) }
  let(:batch) { double('Sidekiq::Batch', description: nil, 'description=': nil) }

  before do
    stub_const('Sidekiq::Batch', Class.new) unless defined?(Sidekiq::Batch)
    allow(Sidekiq::Batch).to receive(:new).and_return(batch)
    allow(batch).to receive(:description=)
    allow(batch).to receive(:jobs).and_yield
  end

  describe '#perform' do
    before do
      allow_any_instance_of(RepresentationManagement::VSOReloader).to receive(:perform)
      allow(Settings).to receive(:vsp_environment).and_return('development')
    end

    context 'with successful XLSX download' do
      before do
        allow(RepresentationManagement::GCLAWS::XlsxClient).to receive(:download_accreditation_xlsx)
          .and_yield({ success: true, file_path: fixture_path })
      end

      it 'calls VSOReloader with the specified types' do
        expect_any_instance_of(RepresentationManagement::VSOReloader)
          .to receive(:perform).with(%w[attorney])

        subject.perform(%w[attorney])
      end

      it 'calls VSOReloader with all types when none specified' do
        expect_any_instance_of(RepresentationManagement::VSOReloader)
          .to receive(:perform).with(described_class::VALID_TYPES)

        subject.perform
      end

      context 'with matching database records' do
        # Fixture has attorney with Number=10000 in MT
        let!(:attorney) do
          create(:accredited_individual, :attorney,
                 registration_number: '10000',
                 raw_address: { 'address_line1' => 'Old Address' },
                 email: 'old@example.com',
                 phone: '555-000-0000')
        end

        # Fixture has VSO with POA=060 in TN
        let!(:organization) do
          create(:accredited_organization,
                 poa_code: '060',
                 raw_address: { 'address_line1' => 'Old Org Address' },
                 name: 'Old Name',
                 phone: '555-000-0001')
        end

        it 'queues individual update jobs for records with changes' do
          expect(RepresentationManagement::AccreditedIndividualsUpdate)
            .to receive(:perform_in).with(0.minutes, anything)

          subject.perform(%w[attorney])
        end

        it 'queues organization update jobs for records with changes' do
          expect(RepresentationManagement::AccreditedOrganizationsUpdate)
            .to receive(:perform_in).with(0.minutes, anything)

          subject.perform(%w[organization])
        end

        it 'does not queue updates for unchanged records' do
          # Update the attorney to match XLSX data so there are no diffs
          attorney.update(
            raw_address: {
              'address_line1' => '82611 Klocko Summit',
              'address_line2' => nil,
              'address_line3' => nil,
              'city' => 'West Rachele',
              'state_code' => 'MT',
              'zip_code' => '59950'
            },
            email: 'maria.glover@goodwin.test',
            phone: '(367) 319-2072'
          )

          expect(RepresentationManagement::AccreditedIndividualsUpdate)
            .not_to receive(:perform_in)

          subject.perform(%w[attorney])
        end
      end
    end

    context 'with failed XLSX download' do
      before do
        allow(RepresentationManagement::GCLAWS::XlsxClient).to receive(:download_accreditation_xlsx)
          .and_yield({ success: false, error: 'Connection refused', status: :service_unavailable })
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(
          /XLSX download failed/
        ).at_least(:once)

        subject.perform
      end

      it 'does not queue any update jobs' do
        allow(Rails.logger).to receive(:error)
        allow(Rails.logger).to receive(:info)

        expect(RepresentationManagement::AccreditedIndividualsUpdate).not_to receive(:perform_in)
        expect(RepresentationManagement::AccreditedOrganizationsUpdate).not_to receive(:perform_in)

        subject.perform
      end
    end

    context 'with invalid types' do
      it 'raises ArgumentError when no valid types provided' do
        expect { subject.perform(['invalid_type']) }.to raise_error(ArgumentError, /No valid entity types/)
      end

      it 'filters out invalid types and processes valid ones' do
        allow(RepresentationManagement::GCLAWS::XlsxClient).to receive(:download_accreditation_xlsx)
          .and_yield({ success: true, file_path: fixture_path })
        allow(Rails.logger).to receive(:error)

        expect_any_instance_of(RepresentationManagement::VSOReloader)
          .to receive(:perform).with(%w[attorney])

        subject.perform(%w[attorney invalid_type])
      end
    end

    context 'when VSOReloader fails' do
      before do
        allow_any_instance_of(RepresentationManagement::VSOReloader)
          .to receive(:perform).and_raise(StandardError.new('VSOReloader failed'))
        allow(Rails.logger).to receive(:error)
        allow(Rails.logger).to receive(:info)
      end

      it 'does not proceed with XLSX download' do
        expect(RepresentationManagement::GCLAWS::XlsxClient)
          .not_to receive(:download_accreditation_xlsx)

        subject.perform
      end
    end

    context 'batching' do
      it 'has SLICE_SIZE of 30' do
        expect(described_class::SLICE_SIZE).to eq(30)
      end
    end
  end
end
