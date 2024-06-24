# frozen_string_literal: true

require 'rails_helper'
require 'dgi/contact_info/response'

describe ContactInfoSerializer, type: :serializer do
  subject { serialize(contact_info_response, serializer_class: described_class) }

  let(:emails) { [{ address: 'test@test.com', dupe: 'false' }] }
  let(:phones) { [{ number: '8013090123', dupe: 'false' }] }
  let(:contact_info_response) do
    response = double('response', body: {
                        'emails' => emails,
                        'phones' => phones
                      })
    MebApi::DGI::ContactInfo::Response.new(201, response)
  end
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :phone' do
    expect_data_eq(attributes['phone'], phones)
  end

  it 'includes :email' do
    expect_data_eq(attributes['email'], emails)
  end
end
