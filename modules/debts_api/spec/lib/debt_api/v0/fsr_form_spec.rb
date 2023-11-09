# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/fsr_form'
RSpec.describe DebtsApi::V0::FsrForm, type: :service do
  describe '#initialize' do
    let(:combined_form_data) { get_fixture_absolute('modules/debts_api/spec/fixtures/fsr_forms/combined_fsr_form') }
    let(:vba_form_data) { get_fixture_absolute('modules/debts_api/spec/fixtures/fsr_forms/vba_fsr_form') }
    let(:vha_form_data) { get_fixture_absolute('modules/debts_api/spec/fixtures/fsr_forms/vha_fsr_form') }
    let(:user) { build(:user, :loa3) }
    let(:user_data) { build(:user_profile_attributes) }

    context 'given a combined fsr' do
      let(:form) { described_class.new(combined_form_data, '123', user) }

      it 'is combined' do
        expect(form.is_combined).to eq(true)
      end

      it 'has a vba form' do
        expect(form.vba_debts.length).to eq(1)
        expect(form.vba_form.present?).to eq(true)
      end

      it 'has vha forms' do
        expect(form.vha_copays.length).to eq(3)
        expect(form.grouped_vha_copays.length).to eq(2)
        expect(form.vha_forms.present?).to eq(true)
        expect(form.vha_forms.length).to eq(form.grouped_vha_copays.length)
      end
    end

    context 'given a vba fsr' do
      let(:form) { described_class.new(vba_form_data, '123', user) }

      it 'is not combined' do
        expect(form.is_combined).to eq(false)
      end

      it 'has a vba form but no vha forms' do
        expect(form.vba_form.present?).to eq(true)
        expect(form.vha_forms.empty?).to eq(true)
      end

      it 'adds compromise ammounts' do
        expected = 'No comments Disability compensation and pension debt compromise amount: $50.00, '
        expect(form.vba_form['additionalData']['additionalComments']).to eq(expected)
      end

      it 'aggregates fsr reasons' do
        expect(form.sanitized_form['personalIdentification']['fsrReason']).to eq(nil)
        expect(form.vba_form['personalIdentification']['fsrReason']).to eq('compromise, monthly')
      end
    end

    context 'given a vha fsr' do
      let(:form) { described_class.new(vha_form_data, '123', user) }

      it 'has a facility num' do
        expect(form.sanitized_form['facilityNum']).to eq(nil)
        expect(form.vha_forms.map { |form| form[:form]['facilityNum'] }).to eq(%w[123 999])
      end

      it 'has a file number' do
        file_number_array = form.vha_forms.map { |form| form[:form]['personalIdentification']['fileNumber'] }.uniq
        expect(file_number_array).to eq([user.ssn])
      end

      it 'does not have debts and copays' do
        expect(form.vha_forms.map { |form| form[:form]['selectedDebtsAndCopays'] }.uniq).to eq([nil])
      end

      it 'is not streamlined' do
        expect(form.is_streamlined).to eq(false)
      end
    end

    context 'given a streamlined fsr' do
      let(:streamlined_form_data) do
        get_fixture_absolute('modules/debts_api/spec/fixtures/fsr_forms/streamlined_fsr_form')
      end
      let(:form) { described_class.new(streamlined_form_data, '123', user) }

      it 'handles a streamlined fsr' do
        expect(form.is_streamlined).to eq(true)
      end

      it 'handles a streamlined false fsr' do
        streamlined_form_data['streamlined'] = { 'value' => false, 'type' => 'none' }
        expect(form.is_streamlined).to eq(false)
      end
    end
  end
end
