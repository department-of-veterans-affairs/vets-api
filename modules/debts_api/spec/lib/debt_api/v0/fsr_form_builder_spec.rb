# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/fsr_form_builder'
RSpec.describe DebtsApi::V0::FsrFormBuilder, type: :service do
  describe '#initialize' do
    let(:combined_form_data) { get_fixture_absolute('modules/debts_api/spec/fixtures/fsr_forms/combined_fsr_form') }
    let(:vba_form_data) { get_fixture_absolute('modules/debts_api/spec/fixtures/fsr_forms/vba_fsr_form') }
    let(:vha_form_data) { get_fixture_absolute('modules/debts_api/spec/fixtures/fsr_forms/vha_fsr_form') }
    let(:user) { build(:user, :loa3) }
    let(:user_data) { build(:user_profile_attributes) }

    context 'all sanitized forms' do
      let(:builder) { described_class.new(combined_form_data, '123', user) }

      it 'adds personal identification' do
        expect(builder.sanitized_form['applicantCertifications']['veteranDateSigned'].present?).to be(true)
      end
    end

    context 'all user forms' do
      let(:builder) { described_class.new(combined_form_data, '123', user) }

      it 'aggregates fsr reasons' do
        expect(builder.sanitized_form['personalIdentification']['fsrReason']).to eq('waiver')
        expect(builder.user_form['personalIdentification']['fsrReason']).to eq('monthly, waiver')
      end
    end

    context 'given a combined fsr' do
      let(:builder) { described_class.new(combined_form_data, '123', user) }

      it 'sets is_combined' do
        expect(builder.is_combined).to eq(true)
      end

      it 'has a vba form' do
        expect(builder.vba_debts.length).to eq(2)
        expect(builder.vba_form.present?).to eq(true)
      end

      it 'has vha forms' do
        expect(builder.vha_copays.length).to eq(3)
        expect(builder.grouped_vha_copays.length).to eq(2)
        expect(builder.vha_forms.present?).to eq(true)
        expect(builder.vha_forms.length).to eq(builder.grouped_vha_copays.length)
      end

      it 'updates vha form\'s additionalComments' do
        comments = builder.vha_forms.first[:form].dig('additionalData', 'additionalComments')
        expect(comments.include?('Combined FSR')).to eq(true)
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
        expect(form.sanitized_form['personalIdentification']['fsrReason']).to eq('')
        expect(form.vba_form['personalIdentification']['fsrReason']).to eq('compromise, monthly')
      end

      it 'does not have debts and copays' do
        expect(form.vba_form['selectedDebtsAndCopays']).to eq(nil)
      end
    end

    context 'given a vha fsr' do
      let(:builder) { described_class.new(vha_form_data, '123', user) }

      it 'has a facility num' do
        expect(builder.sanitized_form['facilityNum']).to eq(nil)
        expect(builder.vha_forms.map { |form| form[:form]['facilityNum'] }).to eq(%w[123 999])
      end

      it 'has a file number' do
        file_number_array = builder.vha_forms.map { |form| form[:form]['personalIdentification']['fileNumber'] }.uniq
        expect(file_number_array).to eq([user.ssn])
      end

      it 'does not have debts and copays' do
        expect(builder.vha_forms.map { |form| form[:form]['selectedDebtsAndCopays'] }.uniq).to eq([nil])
      end

      it 'is not streamlined' do
        expect(builder.is_streamlined).to eq(false)
      end

      it 'parses out delimiter characters' do
        vha_form_data['additional_data']['additional_comments'] = "^Gr\neg|"
        builder = described_class.new(vha_form_data, '123', user)
        vha_comments = builder.vha_forms.first[:form]['additionalData']['additionalComments']
        expect(vha_comments).to eq('Greg , ')
      end

      it 'adds compromise ammounts to comments' do
        compromise_form = vha_form_data.deep_dup
        copays = compromise_form['selected_debts_and_copays']
        copays.first['resolutionOption'] = 'compromise'
        copays.first['deductionCode'] = '30'
        builder = described_class.new(compromise_form, '123', user)
        comments = builder.vha_forms.first[:form].dig('additionalData', 'additionalComments')
        expect(comments.include?('Disability compensation and pension debt')).to eq(true)
      end
    end

    context 'given a streamlined fsr' do
      let(:streamlined_form_data) do
        get_fixture_absolute('modules/debts_api/spec/fixtures/fsr_forms/streamlined_fsr_form')
      end
      let(:combined_form_data) { get_fixture_absolute('modules/debts_api/spec/fixtures/fsr_forms/combined_fsr_form') }
      let(:form_builder) { described_class.new(streamlined_form_data, '123', user) }

      it 'sets is_streamlined' do
        expect(form_builder.is_streamlined).to eq(true)
      end

      it 'sets is_streamlined for explicitly non-streamlined FSRs' do
        streamlined_form_data['streamlined'] = { 'value' => false, 'type' => 'none' }
        expect(form_builder.is_streamlined).to eq(false)
      end

      it 'reflects streamlined status in vha fsr' do
        streamlined_responses = form_builder.vha_forms.map { |form_data| form_data[:form]['streamlined'] }.uniq
        expect(streamlined_responses).to eq([true])
      end

      it 'updates fsrReason' do
        vha_form = form_builder.vha_forms.first[:form]
        reasons = vha_form['personalIdentification']['fsrReason']
        expect(reasons.include?('Automatically Approved')).to eq(true)
      end

      it 'does not change fsrReason for non-streamlined waivers' do
        streamlined_form_data['streamlined'] = { 'value' => false, 'type' => 'none' }
        form_builder = described_class.new(streamlined_form_data, '123', user)
        vha_form = form_builder.vha_forms.first[:form]
        reasons = vha_form['personalIdentification']['fsrReason']
        expect(reasons.include?('Automatically Approved')).to eq(false)
      end

      it 'does not give streamlined status to vba fsr' do
        combined_form_data['streamlined'] = { value: true, type: 'short' }
        combined_builder = described_class.new(combined_form_data, '123', user)
        vba_form = combined_builder.vba_form
        expect(vba_form['streamlined']).to eq(nil)
      end

      it 'purges streamlined data from sanitized form' do
        expect(form_builder.sanitized_form['streamlined']).to eq(nil)
      end

      it 'makes streamlined the last key in the form hash' do
        vha_form = form_builder.vha_forms.first[:form]
        expect(vha_form.keys.last).to eq('streamlined')
      end
    end

    context 'given an fsr that doesnt pass schema' do
      let(:user) { build(:user, :loa3) }
      let(:vba_form_data) { get_fixture_absolute('modules/debts_api/spec/fixtures/fsr_forms/vba_fsr_form') }

      it 'raises FSRInvalidRequest' do
        busted_form = vba_form_data.deep_dup
        busted_form['personal_identification']['ssn'] = 1234
        expect do
          described_class.new(busted_form, '123', user)
        end.to raise_error(DebtsApi::V0::FsrFormBuilder::FSRInvalidRequest)
      end
    end
  end
end
