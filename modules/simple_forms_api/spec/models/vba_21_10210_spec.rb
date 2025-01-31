# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/shared_examples_for_base_form'

RSpec.describe SimpleFormsApi::VBA2110210 do
  it_behaves_like 'zip_code_is_us_based', %w[veteran_mailing_address]

  describe '#notification_first_name' do
    context "preparer's own claim" do
      context 'preparer is veteran' do
        let(:data) do
          {
            'claim_ownership' => 'self',
            'claimant_type' => 'veteran',
            'veteran_full_name' => {
              'first' => 'Veteran',
              'last' => 'Eteranvay'
            }
          }
        end

        it 'returns the veteran first name' do
          expect(described_class.new(data).notification_first_name).to eq 'Veteran'
        end
      end

      context 'preparer is not veteran' do
        let(:data) do
          {
            'claim_ownership' => 'self',
            'claimant_type' => 'non-veteran',
            'claimant_full_name' => {
              'first' => 'Claimant',
              'last' => 'Eteranvay'
            }
          }
        end

        it 'returns the claimant first name' do
          expect(described_class.new(data).notification_first_name).to eq 'Claimant'
        end
      end
    end

    context 'third party claim' do
      let(:data) do
        {
          'claim_ownership' => 'third-party',
          'witness_full_name' => {
            'first' => 'Witness',
            'last' => 'Eteranvay'
          }
        }
      end

      it 'returns the witness first name' do
        expect(described_class.new(data).notification_first_name).to eq 'Witness'
      end
    end
  end

  describe '#notification_email_address' do
    context "preparer's own claim" do
      context 'preparer is veteran' do
        let(:data) do
          {
            'claim_ownership' => 'self',
            'claimant_type' => 'veteran',
            'veteran_email' => 'a@b.com'
          }
        end

        it 'returns the veteran email address' do
          expect(described_class.new(data).notification_email_address).to eq 'a@b.com'
        end
      end

      context 'preparer is not veteran' do
        let(:data) do
          {
            'claim_ownership' => 'self',
            'claimant_type' => 'non-veteran',
            'claimant_email' => 'a@b.com'
          }
        end

        it 'returns the claimant email address' do
          expect(described_class.new(data).notification_email_address).to eq 'a@b.com'
        end
      end
    end

    context 'third party claim' do
      let(:data) do
        {
          'claim_ownership' => 'third-party',
          'witness_email' => 'a@b.com'
        }
      end

      it 'returns the witness email address' do
        expect(described_class.new(data).notification_email_address).to eq 'a@b.com'
      end
    end
  end
end
