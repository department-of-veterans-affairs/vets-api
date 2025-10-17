# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/shared_examples_for_base_form'

RSpec.describe SimpleFormsApi::VBA21p0537 do
  describe '#desired_stamps' do
    context 'when recipient email is shorter than 30 characters' do
      let(:short_email_data) do
        {
          'recipient' => {
            'signature' => 'Test Signature',
            'email' => 'test@va.gov'
          }
        }
      end

      it 'returns the signature stamp' do
        stamps = described_class.new(short_email_data).desired_stamps
        expect(stamps.length).to eq(1) # signature text
        expect(stamps.first[:text]).to eq 'Test Signature'
      end
    end

    context 'when recipient email is longer than 30 characters' do
      let(:long_email_data) do
        {
          'recipient' => {
            'signature' => 'Test Signature',
            'email' => 'thisisanemailaddresswithover30chars@va.gov'
          }
        }
      end

      it 'returns signature, overflow label, and email stamps' do
        stamps = described_class.new(long_email_data).desired_stamps
        expect(stamps.length).to eq(3) # signature, overflow label, email text
        expect(stamps.first[:text]).to eq 'Test Signature'
        expect(stamps.last[:text]).to eq long_email_data.dig('recipient', 'email')
      end
    end
  end
end
