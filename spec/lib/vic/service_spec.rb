# frozen_string_literal: true

require 'rails_helper'

describe VIC::Service do
  let(:parsed_form) { JSON.parse(create(:vic_submission).form) }
  let(:service) { described_class.new }
  let(:user) { build(:evss_user) }

  describe '#get_oauth_token' do
    it 'should get the access token from the request', run_at: '2018-02-06 21:51:48 -0500' do
      oauth_params = get_fixture('vic/oauth_params').symbolize_keys
      return_val = OpenStruct.new(body: { 'access_token' => 'token' })
      expect(service).to receive(:request).with(:post, '', oauth_params).and_return(return_val)

      expect(service.get_oauth_token).to eq('token')
    end
  end

  describe '#add_user_data!' do
    it 'should add user data to the request form' do
      converted_form = { "profile_data" => {} }
      expect(user.veteran_status).to receive(:title38_status).and_return('V1')
      service.add_user_data!(converted_form, user)
      expect(converted_form).to eq(
        {"profile_data"=>{"sec_ID"=>"0001234567", "active_ICN"=>user.icn}, "title38_status"=>"V1 - Title 38 Veteran"}
      )
    end
  end

  describe '#convert_form' do
    it 'should format the form' do
      expect(service.convert_form(parsed_form)).to eq(
        {"service_branch"=>"Air Force",
         "email"=>"foo@foo.com",
         "veteran_full_name"=>{"first"=>"Mark", "last"=>"Olson"},
         "veteran_address"=>{"city"=>"Milwaukee", "country"=>"US", "postal_code"=>"53130", "state"=>"WI", "street"=>"123 Main St", "street2"=>""},
         "phone"=>"5551110000",
         "profile_data"=>{"SSN"=>"111223333"}}
      )
    end
  end

  describe '#submit' do
    context 'with a user' do
      it 'should submit the form and attached documents' do
        VCR.config do |c|
          c.allow_http_connections_when_no_cassette = true
        end

        described_class.new.submit(parsed_form, user)
      end
    end

    context 'with no user' do
      it 'should submit the form' do
        VCR.config do |c|
          c.allow_http_connections_when_no_cassette = true
        end

        described_class.new.submit(parsed_form)
      end
    end
  end
end
