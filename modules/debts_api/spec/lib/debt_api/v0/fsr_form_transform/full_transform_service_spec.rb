# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/fsr_form_transform/full_transform_service'

RSpec.describe DebtsApi::V0::FsrFormTransform::FullTransformService, type: :service do
  

  describe '#transform' do

    context 'standard FSR' do
      let(:pre_transform_fsr_form_data) do
        get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/pre_transform')
      end
      let(:post_transform_fsr_form_data) do
        get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/post_transform')
      end 
      let(:transformed) do 
        described_class.new(pre_transform_fsr_form_data).transform
      end
      it 'generates personalIdentification' do
        expect(transformed['personalIdentification']).to eq(post_transform_fsr_form_data['personalIdentification'])
      end
      it 'generates personalData' do
        expect(transformed['personalData']).to eq(post_transform_fsr_form_data['personalData'])
      end
      it 'generates income' do
        expect(transformed['income']).to eq(post_transform_fsr_form_data['income'])
      end
      it 'generates expenses' do
        expect(transformed['expenses']).to eq(post_transform_fsr_form_data['expenses'])
      end
      it 'generates discretionaryIncome' do
        expect(transformed['discretionaryIncome']).to eq(post_transform_fsr_form_data['discretionaryIncome'])
      end
      it 'generates assets' do
        expect(transformed['assets']).to eq(post_transform_fsr_form_data['assets'])
      end
      it 'generates installmentContractsAndOtherDebts' do
        expect(transformed['installmentContractsAndOtherDebts']).to eq(post_transform_fsr_form_data['installmentContractsAndOtherDebts'])
      end
      it 'generates totalOfInstallmentContractsAndOtherDebts' do
        expect(transformed['totalOfInstallmentContractsAndOtherDebts']).to eq(post_transform_fsr_form_data['totalOfInstallmentContractsAndOtherDebts'])
      end
      it 'generates additionalData' do
        expect(transformed['additionalData']).to eq(post_transform_fsr_form_data['additionalData'])
      end
      it 'generates applicantCertifications' do
        expect(transformed['applicantCertifications']['veteranSignature']).to eq(post_transform_fsr_form_data['applicantCertifications']['veteranSignature'])
        expect(transformed['applicantCertifications']['veteranDateSigned']).to eq(Date.today.strftime('%m/%d/%Y'))
      end
      it 'generates selectedDebtsAndCopays' do
        expect(transformed['selectedDebtsAndCopays']).to eq(post_transform_fsr_form_data['selectedDebtsAndCopays'])
      end
      it 'generates streamlined' do
        expect(transformed['streamlined']).to eq(post_transform_fsr_form_data['streamlined'])
      end
    end

    context 'streamlined short FSR' do
      let(:pre_transform_fsr_form_data) do
        get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/kitchen_sink/pre_transform')
      end
      let(:post_transform_fsr_form_data) do
        get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/kitchen_sink/post_transform')
      end 
      let(:transformed) do 
        described_class.new(pre_transform_fsr_form_data).transform
      end
      it 'generates personalIdentification' do
        expect(transformed['personalIdentification']).to eq(post_transform_fsr_form_data['personalIdentification'])
      end
      it 'generates personalData' do
        expect(transformed['personalData']).to eq(post_transform_fsr_form_data['personalData'])
      end
      it 'generates income' do
        expect(transformed['income']).to eq(post_transform_fsr_form_data['income'])
      end
      it 'generates expenses' do
        expect(transformed['expenses']).to eq(post_transform_fsr_form_data['expenses'])
      end
      it 'generates discretionaryIncome' do
        expect(transformed['discretionaryIncome']).to eq(post_transform_fsr_form_data['discretionaryIncome'])
      end
      it 'generates assets' do
        expect(transformed['assets']).to eq(post_transform_fsr_form_data['assets'])
      end
      it 'generates installmentContractsAndOtherDebts' do
        expect(transformed['installmentContractsAndOtherDebts']).to eq(post_transform_fsr_form_data['installmentContractsAndOtherDebts'])
      end
      it 'generates totalOfInstallmentContractsAndOtherDebts' do
        expect(transformed['totalOfInstallmentContractsAndOtherDebts']).to eq(post_transform_fsr_form_data['totalOfInstallmentContractsAndOtherDebts'])
      end
      it 'generates additionalData' do
        expect(transformed['additionalData']).to eq(post_transform_fsr_form_data['additionalData'])
      end
      it 'generates applicantCertifications' do
        expect(transformed['applicantCertifications']['veteranSignature']).to eq(post_transform_fsr_form_data['applicantCertifications']['veteranSignature'])
        expect(transformed['applicantCertifications']['veteranDateSigned']).to eq(Date.today.strftime('%m/%d/%Y'))
      end
      it 'generates selectedDebtsAndCopays' do
        expect(transformed['selectedDebtsAndCopays']).to eq(post_transform_fsr_form_data['selectedDebtsAndCopays'])
      end
      it 'generates streamlined' do
        expect(transformed['streamlined']).to eq(post_transform_fsr_form_data['streamlined'])
      end
    end
  end
end
