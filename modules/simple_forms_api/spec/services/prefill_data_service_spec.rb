# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

describe SimpleFormsApi::PrefillDataService do
  describe '#check_for_changes' do
    let(:form_id) { '21-0779' }
    let(:rails_logger) { double }
    let(:prefill_data) do
      {
        'full_name' => {
          'first' => 'fake-first-name',
          'last' => 'fake-last-name'
        },
        'address' => {
          'postal_code' => '12345'
        },
        'veteran' => {
          'ssn' => 'fake-ssn'
        },
        'email' => 'fake-email'
      }
    end
    let(:form_data) do
      {
        'full_name' => {
          'first' => 'fake-first-name',
          'last' => 'fake-last-name'
        },
        'postal_code' => '12345',
        'id_number' => {
          'ssn' => 'fake-ssn'
        },
        'email' => 'fake-email'
      }
    end
    let(:prefill_data_service) do
      SimpleFormsApi::PrefillDataService.new(
        prefill_data: prefill_data.to_json, form_data: modified_form_data,
        form_id:
      )
    end

    before { allow(Rails).to receive(:logger).and_return(rails_logger) }

    context 'first_name does not match' do
      let(:modified_form_data) do
        form_data.merge({ 'full_name' => {
                          'first' => 'new-first-name',
                          'last' => 'fake-last-name'
                        } })
      end

      it 'logs the first_name change' do
        expect(rails_logger).to receive(:info).with('Simple forms api - Form Upload Flow changed data',
                                                    { field: :first_name, form_id: })

        prefill_data_service.check_for_changes
      end
    end

    context 'last_name does not match' do
      let(:modified_form_data) do
        form_data.merge({ 'full_name' => {
                          'first' => 'fake-first-name',
                          'last' => 'new-last-name'
                        } })
      end

      it 'logs the last_name change' do
        expect(rails_logger).to receive(:info).with('Simple forms api - Form Upload Flow changed data',
                                                    { field: :last_name, form_id: })

        prefill_data_service.check_for_changes
      end
    end

    context 'postal_code does not match' do
      let(:modified_form_data) do
        form_data.merge({ 'postal_code' => '67890' })
      end

      it 'logs the postal_code change' do
        expect(rails_logger).to receive(:info).with('Simple forms api - Form Upload Flow changed data',
                                                    { field: :postal_code, form_id: })

        prefill_data_service.check_for_changes
      end
    end

    context 'ssn does not match' do
      let(:modified_form_data) do
        form_data.merge({ 'id_number' => { 'ssn' => 'new-ssn' } })
      end

      it 'logs the ssn change' do
        expect(rails_logger).to receive(:info).with('Simple forms api - Form Upload Flow changed data',
                                                    { field: :ssn, form_id: })

        prefill_data_service.check_for_changes
      end
    end

    context 'email does not match' do
      let(:modified_form_data) do
        form_data.merge({ 'email' => 'new-email' })
      end

      it 'logs the email change' do
        expect(rails_logger).to receive(:info).with('Simple forms api - Form Upload Flow changed data',
                                                    { field: :email, form_id: })

        prefill_data_service.check_for_changes
      end
    end
  end
end
