# frozen_string_literal: true
require 'rails_helper'
require 'evss/mhvcf/client'

describe 'evss mhvcf' do
  subject(:client) { EVSS::MHVCF::Client.new }
  let(:user) { build(:evss_user) }

  # This code is deliberately commented out. Here for testing purposes only.
  # it 'gets form configs', :vcr do
  #   expect(client.user(user).get_get_form_configs).to eq({})
  # end

  it 'searches for inflight forms', :vcr do
    expect(client.user(user).post_get_in_flight_forms).to eq({})
  end

  context 'form submital' do
    let(:valid_attrs) do
      {
        patient_full_name: [user.first_name, user.middle_name, user.last_name].compact.join(' '),
        ssn: user.ssn,
        ssn_masked: '*' * 5 + user.ssn.chars.last(4).join,
        dob: user.birth_date.strftime('%d/%m/%Y'),
        patient_phone_number: nil,
        date_sign: Time.current.strftime('%d/%m/%Y')
      }
    end

    it 'raises errors if form is invalid' do
      expect { client.user(user).post_submit_form({}) }
        .to raise_error(Common::Exceptions::ValidationErrors)
    end

    it 'submits the form', :vcr do
      expect(client.user(user).post_submit_form(valid_attrs))
    end
  end
end
