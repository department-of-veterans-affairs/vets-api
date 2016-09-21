# frozen_string_literal: true
require 'rails_helper'

describe SM::Configuration do
  it 'should raise an ArgumentError if no parameters passed' do
    expect { described_class.new }.to raise_error(ArgumentError, 'missing keywords: host, app_token')
  end

  it 'should raise an ArgumentError if host name is not ssl' do
    expect { described_class.new(host: 'http://test.com', app_token: 'token') }
      .to raise_error(ArgumentError, 'host must use ssl')
  end

  context 'with valid attributes' do
    let(:options) { { host: 'https://test.com', app_token: 'token', open_timeout: 25 } }
    subject { described_class.new(options) }

    it 'should have certain attributes' do
      expect(subject).to have_attributes(app_token: 'token', open_timeout: 25, read_timeout: 15,
                                         base_path: 'https://test.com/mhv-sm-api/patient/v1/')
    end
  end
end
