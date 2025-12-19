# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/fsr_form_transform/full_transform_service'

RSpec.describe DebtsApi::V0::FsrFormTransform::FullTransformService, type: :service do
  describe '#transform' do
    context 'standard FSR' do
      let(:pre_transform_fsr_form_data) do
        get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/pre_transform')
      end
      let(:post_transform_fsr) do
        get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/post_transform')
      end
      let(:transformed) do
        described_class.new(pre_transform_fsr_form_data).transform
      end

      it 'reports streamlined and type' do
        expect(StatsD).to receive(:increment).with('api.fsr_submission.full_transform.no_streamlined_data')
        expect(StatsD).to receive(:increment).with('api.fsr_submission.none_streamlined_type')

        transformed
      end

      it 'generates personalIdentification' do
        expect(transformed['personalIdentification']).to eq(post_transform_fsr['personalIdentification'])
      end

      it 'generates personalData' do
        expect(transformed['personalData']).to eq(post_transform_fsr['personalData'])
      end

      it 'generates income' do
        expect(transformed['income']).to eq(post_transform_fsr['income'])
      end

      it 'generates expenses' do
        expect(transformed['expenses']).to eq(post_transform_fsr['expenses'])
      end

      it 'generates discretionaryIncome' do
        expect(transformed['discretionaryIncome']).to eq(post_transform_fsr['discretionaryIncome'])
      end

      it 'generates assets' do
        expect(transformed['assets']).to eq(post_transform_fsr['assets'])
      end

      it 'generates installmentContractsAndOtherDebts' do
        transformed_installments = transformed['installmentContractsAndOtherDebts']
        expect(transformed_installments).to eq(post_transform_fsr['installmentContractsAndOtherDebts'])
      end

      it 'generates totalOfInstallmentContractsAndOtherDebts' do
        transformed_total_installments = transformed['totalOfInstallmentContractsAndOtherDebts']
        expect(transformed_total_installments).to eq(post_transform_fsr['totalOfInstallmentContractsAndOtherDebts'])
      end

      it 'generates additionalData' do
        transformed_addl_data = transformed['additionalData']
        expect(transformed_addl_data).to eq(post_transform_fsr['additionalData'])
      end

      it 'generates applicantCertifications' do
        trans_signature = transformed['applicantCertifications']['veteranSignature']
        expect(trans_signature).to eq(post_transform_fsr['applicantCertifications']['veteranSignature'])
        expect(transformed['applicantCertifications']['veteranDateSigned']).to eq(Time.zone.today.strftime('%m/%d/%Y'))
      end

      it 'generates selectedDebtsAndCopays' do
        expect(transformed['selectedDebtsAndCopays']).to eq(post_transform_fsr['selectedDebtsAndCopays'])
      end

      it 'generates streamlined' do
        expect(transformed['streamlined']).to eq(post_transform_fsr['streamlined'])
      end
    end

    context 'maximal FSR' do
      let(:pre_transform_fsr_form_data) do
        get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/kitchen_sink/pre_transform')
      end
      let(:post_transform_fsr) do
        get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/kitchen_sink/post_transform')
      end
      let(:transformed) do
        described_class.new(pre_transform_fsr_form_data).transform
      end

      it 'generates personalIdentification' do
        expect(transformed['personalIdentification']).to eq(post_transform_fsr['personalIdentification'])
      end

      it 'generates personalData' do
        expect(transformed['personalData']).to eq(post_transform_fsr['personalData'])
      end

      it 'generates income' do
        expect(transformed['income']).to eq(post_transform_fsr['income'])
      end

      it 'generates expenses' do
        expect(transformed['expenses']).to eq(post_transform_fsr['expenses'])
      end

      it 'generates discretionaryIncome' do
        expect(transformed['discretionaryIncome']).to eq(post_transform_fsr['discretionaryIncome'])
      end

      it 'generates assets' do
        expect(transformed['assets']).to eq(post_transform_fsr['assets'])
      end

      it 'generates installmentContractsAndOtherDebts' do
        trans_installments = transformed['installmentContractsAndOtherDebts']
        expect(trans_installments).to eq(post_transform_fsr['installmentContractsAndOtherDebts'])
      end

      it 'generates totalOfInstallmentContractsAndOtherDebts' do
        trans_total_installments = transformed['totalOfInstallmentContractsAndOtherDebts']
        expect(trans_total_installments).to eq(post_transform_fsr['totalOfInstallmentContractsAndOtherDebts'])
      end

      it 'generates additionalData' do
        expect(transformed['additionalData']).to eq(post_transform_fsr['additionalData'])
      end

      it 'generates applicantCertifications' do
        trans_sig = transformed['applicantCertifications']['veteranSignature']
        expect(trans_sig).to eq(post_transform_fsr['applicantCertifications']['veteranSignature'])
        expect(transformed['applicantCertifications']['veteranDateSigned']).to eq(Time.zone.today.strftime('%m/%d/%Y'))
      end

      it 'generates selectedDebtsAndCopays' do
        expect(transformed['selectedDebtsAndCopays']).to eq(post_transform_fsr['selectedDebtsAndCopays'])
      end

      it 'generates streamlined' do
        expect(transformed['streamlined']).to eq(post_transform_fsr['streamlined'])
      end
    end

    context 'streamlined short FSR' do
      let(:pre_transform_fsr_form_data) do
        get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/sw_short/minimal_asset_pre_transform')
      end
      let(:post_transform_fsr) do
        get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/sw_short/minimal_asset_post_transform')
      end
      let(:transformed) do
        described_class.new(pre_transform_fsr_form_data).transform
      end

      it 'generates personalIdentification' do
        expect(transformed['personalIdentification']).to eq(post_transform_fsr['personalIdentification'])
      end

      it 'generates personalData' do
        expect(transformed['personalData']).to eq(post_transform_fsr['personalData'])
      end

      it 'generates income' do
        expect(transformed['income']).to eq(post_transform_fsr['income'])
      end

      it 'generates expenses' do
        expect(transformed['expenses']).to eq(post_transform_fsr['expenses'])
      end

      it 'generates discretionaryIncome' do
        expect(transformed['discretionaryIncome']).to eq(post_transform_fsr['discretionaryIncome'])
      end

      it 'generates assets' do
        expect(transformed['assets']).to eq(post_transform_fsr['assets'])
      end

      it 'generates installmentContractsAndOtherDebts' do
        trans_installments = transformed['installmentContractsAndOtherDebts']
        expect(trans_installments).to eq(post_transform_fsr['installmentContractsAndOtherDebts'])
      end

      it 'generates totalOfInstallmentContractsAndOtherDebts' do
        trans_total_installments = transformed['totalOfInstallmentContractsAndOtherDebts']
        expect(trans_total_installments).to eq(post_transform_fsr['totalOfInstallmentContractsAndOtherDebts'])
      end

      it 'generates additionalData' do
        expect(transformed['additionalData']).to eq(post_transform_fsr['additionalData'])
      end

      it 'generates applicantCertifications' do
        trans_sig = transformed['applicantCertifications']['veteranSignature']
        expect(trans_sig).to eq(post_transform_fsr['applicantCertifications']['veteranSignature'])
        expect(transformed['applicantCertifications']['veteranDateSigned']).to eq(Time.zone.today.strftime('%m/%d/%Y'))
      end

      it 'generates selectedDebtsAndCopays' do
        expect(transformed['selectedDebtsAndCopays']).to eq(post_transform_fsr['selectedDebtsAndCopays'])
      end

      it 'generates streamlined' do
        expect(transformed['streamlined']).to eq(post_transform_fsr['streamlined'])
      end
    end

    context 'streamlined long FSR' do
      let(:pre_transform_fsr_form_data) do
        get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/sw_long/minimal_asset_pre_transform')
      end
      let(:post_transform_fsr) do
        get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/sw_long/minimal_asset_post_transform')
      end
      let(:transformed) do
        described_class.new(pre_transform_fsr_form_data).transform
      end

      it 'generates personalIdentification' do
        expect(transformed['personalIdentification']).to eq(post_transform_fsr['personalIdentification'])
      end

      it 'generates personalData' do
        expect(transformed['personalData']).to eq(post_transform_fsr['personalData'])
      end

      it 'generates income' do
        expect(transformed['income']).to eq(post_transform_fsr['income'])
      end

      it 'generates expenses' do
        expect(transformed['expenses']).to eq(post_transform_fsr['expenses'])
      end

      it 'generates discretionaryIncome' do
        expect(transformed['discretionaryIncome']).to eq(post_transform_fsr['discretionaryIncome'])
      end

      it 'generates assets' do
        expect(transformed['assets']).to eq(post_transform_fsr['assets'])
      end

      it 'generates installmentContractsAndOtherDebts' do
        trans_installments = transformed['installmentContractsAndOtherDebts']
        expect(trans_installments).to eq(post_transform_fsr['installmentContractsAndOtherDebts'])
      end

      it 'generates totalOfInstallmentContractsAndOtherDebts' do
        trans_total_installments = transformed['totalOfInstallmentContractsAndOtherDebts']
        expect(trans_total_installments).to eq(post_transform_fsr['totalOfInstallmentContractsAndOtherDebts'])
      end

      it 'generates additionalData' do
        expect(transformed['additionalData']).to eq(post_transform_fsr['additionalData'])
      end

      it 'generates applicantCertifications' do
        trans_sig = transformed['applicantCertifications']['veteranSignature']
        expect(trans_sig).to eq(post_transform_fsr['applicantCertifications']['veteranSignature'])
        expect(transformed['applicantCertifications']['veteranDateSigned']).to eq(Time.zone.today.strftime('%m/%d/%Y'))
      end

      it 'generates selectedDebtsAndCopays' do
        expect(transformed['selectedDebtsAndCopays']).to eq(post_transform_fsr['selectedDebtsAndCopays'])
      end

      it 'generates streamlined' do
        expect(transformed['streamlined']).to eq(post_transform_fsr['streamlined'])
      end
    end
  end
end
