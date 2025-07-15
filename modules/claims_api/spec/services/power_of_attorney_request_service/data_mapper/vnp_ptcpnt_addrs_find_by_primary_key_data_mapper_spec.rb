# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::DataMapper::VnpPtcpntAddrsFindByPrimaryKeyDataMapper do
  subject { described_class.new(record:) }

  let(:record) do
    {
      addrs_one_txt: '2719 Atlas Ave',
      addrs_two_txt: 'Apt 2',
      city_nm: 'Los Angeles',
      cntry_nm: 'USA',
<<<<<<< HEAD
      postal_cd: 'CA',
=======
>>>>>>> 05485bf6ad (Fixes naming on files to be inline with previous mapper files)
      zip_first_suffix_nbr: '0200',
      zip_prefix_nbr: '92264'
    }
  end

  let(:expected_data_obj) do
    {
<<<<<<< HEAD
      'addrs_one_txt' => '2719 Atlas Ave',
      'addrs_two_txt' => 'Apt 2',
      'city_nm' => 'Los Angeles',
      'cntry_nm' => 'USA',
      'postal_cd' => 'CA',
      'zip_prefix_nbr' => '92264',
      'zip_first_suffix_nbr' => '0200',
      'email_addrs_txt' => nil
=======
      addrs_one_txt: '2719 Atlas Ave',
      addrs_two_txt: 'Apt 2',
      city_nm: 'Los Angeles',
      cntry_nm: 'USA',
      prvnc_nm: nil,
      zip_prefix_nbr: '92264',
      zip_first_suffix_nbr: '0200',
      email_addrs_txt: nil
>>>>>>> 05485bf6ad (Fixes naming on files to be inline with previous mapper files)
    }
  end

  context 'Mapping the POA data object' do
    it 'gathers the expected data based on the params' do
      res = subject.call

      expect(res).to eq(expected_data_obj)
    end
  end
end
