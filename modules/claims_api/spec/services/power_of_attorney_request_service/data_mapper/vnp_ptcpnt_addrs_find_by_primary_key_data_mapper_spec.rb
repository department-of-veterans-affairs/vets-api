# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::DataMapper::VnpPtcpntAddrsFindByPrimaryKeyDataMapper do
  subject { described_class.new(record:) }

  let(:record) do
    {
<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> 2d0b7b7aa2 (Merges in upstream, fixes conflicts and cleans up requests to match)
      addrs_one_txt: '2719 Atlas Ave',
      addrs_two_txt: 'Apt 2',
      city_nm: 'Los Angeles',
      cntry_nm: 'USA',
<<<<<<< HEAD
<<<<<<< HEAD
      postal_cd: 'CA',
=======
>>>>>>> 05485bf6ad (Fixes naming on files to be inline with previous mapper files)
      zip_first_suffix_nbr: '0200',
      zip_prefix_nbr: '92264'
=======
      'addrs_one_txt' => '2719 Atlas Ave',
      'addrs_two_txt' => 'Apt 2',
      'city_nm' => 'Los Angeles',
      'cntry_nm' => 'USA',
      'zip_first_suffix_nbr' => '0200',
      'zip_prefix_nbr' => '92264'
>>>>>>> 58184e4087 (API-43735-gather-data-for-poa-accept-2)
=======
      zip_first_suffix_nbr: '0200',
      zip_prefix_nbr: '92264'
>>>>>>> 2d0b7b7aa2 (Merges in upstream, fixes conflicts and cleans up requests to match)
    }
  end

  let(:expected_data_obj) do
    {
<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> 58184e4087 (API-43735-gather-data-for-poa-accept-2)
      'addrs_one_txt' => '2719 Atlas Ave',
      'addrs_two_txt' => 'Apt 2',
      'city_nm' => 'Los Angeles',
      'cntry_nm' => 'USA',
<<<<<<< HEAD
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
=======
      'prvnc_nm' => nil,
      'zip_prefix_nbr' => '92264',
      'zip_first_suffix_nbr' => '0200',
      'email_addrs_txt' => nil
>>>>>>> 58184e4087 (API-43735-gather-data-for-poa-accept-2)
    }
  end

  context 'Mapping the POA data object' do
    it 'gathers the expected data based on the params' do
      res = subject.call

      expect(res).to eq(expected_data_obj)
    end
  end
end
