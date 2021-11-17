# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MedicalCopays::VBS::Service do
  subject { described_class.build(user: user) }

  let(:user) { build(:user, :loa3) }

  describe 'attributes' do
    it 'responds to request' do
      expect(subject.respond_to?(:request)).to be(true)
    end

    it 'responds to request_data' do
      expect(subject.respond_to?(:request_data)).to be(true)
    end
  end

  describe '.build' do
    it 'returns an instance of Service' do
      expect(subject).to be_an_instance_of(MedicalCopays::VBS::Service)
    end
  end

  describe '#get_copays' do
    it 'raises a custom error when request data is invalid' do
      allow_any_instance_of(MedicalCopays::VBS::RequestData).to receive(:valid?).and_return(false)

      expect { subject.get_copays }.to raise_error(MedicalCopays::VBS::InvalidVBSRequestError)
    end

    it 'returns a response hash' do
      url = '/base/path/GetStatementsByEDIPIAndVistaAccountNumber'
      data = { edipi: '123456789', vistaAccountNumbers: [36_546] }
      response = Faraday::Response.new(body: [{ 'foo_bar' => 'bar' }], status: 200)

      allow_any_instance_of(MedicalCopays::VBS::RequestData).to receive(:valid?).and_return(true)
      allow_any_instance_of(MedicalCopays::VBS::RequestData).to receive(:to_hash).and_return(data)
      allow_any_instance_of(MedicalCopays::Request).to receive(:post).with(url, data).and_return(response)

      expect(subject.get_copays).to eq({ data: [{ 'fooBar' => 'bar' }], status: 200 })
    end

    it 'includes zero balance statements if available' do
      url = '/base/path/GetStatementsByEDIPIAndVistaAccountNumber'
      data = { edipi: '123456789', vistaAccountNumbers: [36_546] }
      response = Faraday::Response.new(body: [{ 'foo_bar' => 'bar' }], status: 200)
      zero_balance_response = [{ 'bar_baz' => 'baz' }]

      allow_any_instance_of(MedicalCopays::VBS::RequestData).to receive(:valid?).and_return(true)
      allow_any_instance_of(MedicalCopays::VBS::RequestData).to receive(:to_hash).and_return(data)
      allow_any_instance_of(MedicalCopays::Request).to receive(:post).with(url, data).and_return(response)
      allow_any_instance_of(MedicalCopays::ZeroBalanceStatements).to receive(:list).and_return(zero_balance_response)

      expect(subject.get_copays).to eq({ data: [{ 'fooBar' => 'bar' }, { 'barBaz' => 'baz' }], status: 200 })
    end
  end
end
