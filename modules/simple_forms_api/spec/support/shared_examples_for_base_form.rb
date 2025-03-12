# frozen_string_literal: true

RSpec.shared_examples 'zip_code_is_us_based' do |address_keys|
  subject(:zip_code_is_us_based) { described_class.new(data).zip_code_is_us_based }

  address_keys.each do |address_key|
    context 'address is present and in US' do
      let(:data) { { address_key => { 'country' => 'USA' } } }

      it 'returns true' do
        expect(zip_code_is_us_based).to be(true)
      end
    end

    context 'address is present and not in US' do
      let(:data) { { address_key => { 'country' => 'CAN' } } }

      it 'returns false' do
        expect(zip_code_is_us_based).to be(false)
      end
    end
  end

  context 'no valid address is given' do
    let(:data) { {} }

    it 'returns false' do
      expect(zip_code_is_us_based).to be(false)
    end
  end
end
