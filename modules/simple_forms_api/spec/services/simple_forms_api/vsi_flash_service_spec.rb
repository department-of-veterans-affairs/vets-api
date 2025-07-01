# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SimpleFormsApi::VsiFlashService do
  let(:form_data) { {} }
  let(:service) { described_class.new(form_data) }
  let(:bgs_service) { instance_double(BGS::Services) }
  let(:claimant_service) { double }

  before do
    allow(BGS::Services).to receive(:new).and_return(bgs_service)
    allow(bgs_service).to receive(:claimant).and_return(claimant_service)
  end

  describe '#add_flash_to_bgs' do
    context 'when SSN is missing' do
      it 'returns false' do
        expect(service.add_flash_to_bgs).to be false
      end

      it 'does not call BGS service' do
        expect(BGS::Services).not_to receive(:new)
        service.add_flash_to_bgs
      end
    end

    context 'when SSN is present and service works' do
      let(:ssn) { '123456789' }
      let(:form_data) do
        {
          'veteran_id' => { 'ssn' => ssn }
        }
      end

      before do
        allow(claimant_service).to receive(:add_flash)
        allow(claimant_service).to receive(:find_assigned_flashes).and_return(
          { flashes: [{ flash_name: 'VSI' }] }
        )
      end

      it 'returns true' do
        expect(service.add_flash_to_bgs).to be true
      end
    end

    context 'when flash is added but confirmation fails' do
      let(:ssn) { '123456789' }
      let(:form_data) do
        {
          'veteran_id' => { 'ssn' => ssn }
        }
      end

      before do
        allow(claimant_service).to receive(:add_flash)
        allow(claimant_service).to receive(:find_assigned_flashes).and_return(
          { flashes: [{ flash_name: 'OTHER_FLASH' }] }
        )
      end

      it 'logs confirmation failure and returns true' do
        expect(Rails.logger).to receive(:error).with(
          'Simple Forms API - Failed to Confirm VSI Flash Addition',
          { form_id: '20-10207' }
        )
        expect(service.add_flash_to_bgs).to be true
      end
    end

    context 'when service fails' do
      let(:ssn) { '123456789' }
      let(:form_data) do
        {
          'veteran_id' => { 'ssn' => ssn }
        }
      end

      before do
        allow(claimant_service).to receive(:add_flash).and_raise(StandardError, 'BGS error')
      end

      it 'returns false' do
        expect(service.add_flash_to_bgs).to be false
      end
    end
  end
end
