# frozen_string_literal: true
require 'rails_helper'
require 'mhv/configuration'

describe MHV::Configuration do
  let(:host) { 'https://www.example.com' }
  let(:base_path) { '/mhv-portal-web/user-registration' }
  subject { described_class.new(host: host, app_token: 'csrf_token') }

  it 'should respond to query_string returning as a url encoded query string' do
    expect(subject.query_string)
      .to eq('')
  end

  it 'should respond to base_path returning fully qualified url with host and query string' do
    expect(subject.base_path)
      .to eq("#{host}#{base_path}?#{subject.query_string}")
  end
end
