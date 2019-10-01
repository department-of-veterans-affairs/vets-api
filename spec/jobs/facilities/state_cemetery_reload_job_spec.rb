# frozen_string_literal: true

require 'rails_helper'
require 'facilities/bulk_json_client'

RSpec.describe Facilities::StateCemeteryReloadJob, type: :job do
  let(:cemetery_data) do
    %q(<cems>
         <cem fac_id="1001" state="ALABAMA" statecode="AL"
         cem_name="Alabama State Veterans Memorial Cemetery At Spanish Fort"
         cem_url="http://www.va.state.al.us/spanishfort.aspx" funded="YES"
         address_line1="34904 State Highway 225" address_line2="Spanish Fort, AL 36577"
         address_line3="" mailing_line1="" mailing_line2="" mailing_line3=""
         contact1="Tony Ross, Cemetery Director" contact2="Joseph S. Buschell, Assistant Cemetery Director"
         phone="251-625-1338" fax="251-626-9204" email="" lat="30.7346233" long="-87.8985442" stationid="400" />
         <cem fac_id="1002" state="ARIZONA" statecode="AZ"

         cem_name="Arizona Veterans' Memorial Cemetery at Camp Navajo"
         cem_url="https://dvs.az.gov/arizona-veterans-memorial-cemetery-camp-navajo" funded="YES"
         address_line1="14317 Veterans Drive, Camp Navajo" address_line2="PO Box 16419"
         address_line3="Bellemont, AZ 86015" mailing_line1="" mailing_line2="" mailing_line3=""
         contact1="LTC Andrew Griffin, USAF, Ret., Ed.D., Cemetery Administrator"
         contact2="Arizona Department of Veterans' Services" phone="928-214-3474" fax="928-214-3479"
         email="" lat="35.236695369857" long="-111.845053851604" stationid="412" />

         <cem fac_id="1003" state="ARIZONA" statecode="AZ" cem_name="Arizona Veterans' Memorial Cemetery at Marana"
         cem_url="https://dvs.az.gov/arizona-veterans-memorial-cemetery-marana" funded="YES"
         address_line1="15950 N Luckett Road" address_line2="" address_line3="" mailing_line1="" mailing_line2=""
         mailing_line3="" contact1="Bonnie L. Dudelston, Cemetery Administrator" contact2="" phone="520-638-4869"
         fax="520-638-4899" email="" lat="32.4948489724764" long="-111.270155549049" stationid="413" />
      </cems>)
  end

  before(:each) do
    allow_any_instance_of(
      Facilities::StateCemeteryReloadJob
    ).to receive(:fetch_cemeteries).and_return(Nokogiri::XML(cemetery_data))
  end

  it 'should purge existing state cemetery data' do
    create :nca_888, classification: 'State Cemetery'
    expect(Facilities::NCAFacility.count).to eq(1)
    Facilities::StateCemeteryReloadJob.new.perform
    expect(Facilities::NCAFacility.where(unique_id: '888').count).to eq(0)
  end

  it 'should not change other cemetery data' do
    create :nca_888
    expect(Facilities::NCAFacility.count).to eq(1)
    Facilities::StateCemeteryReloadJob.new.perform
    expect(Facilities::NCAFacility.where(unique_id: '888').count).to eq(1)
  end

  it 'should load state cemetery data from our data file' do
    Facilities::StateCemeteryReloadJob.new.perform
    cemetery = Facilities::NCAFacility.first
    expect(cemetery.unique_id).to eq('s1001')
    expect(cemetery.name).to eq('Alabama State Veterans Memorial Cemetery At Spanish Fort')
    expect(cemetery.address['physical']['address_1']).to eq('34904 State Highway 225')
    expect(cemetery.address['physical']['city']).to eq('Spanish Fort')
    expect(cemetery.address['physical']['state']).to eq('AL')
    expect(cemetery.address['physical']['zip']).to eq('36577')
    expect(cemetery.website).to eq('http://www.va.state.al.us/spanishfort.aspx')
    expect(cemetery.lat).to eq(30.7346233)
    expect(cemetery.long).to eq(-87.8985442)
    expect(cemetery.phone['main']).to eq('251-625-1338')
    expect(cemetery.phone['fax']).to eq('251-626-9204')
  end

  it 'should make addresses an empty hash if address data is blank' do
    Facilities::StateCemeteryReloadJob.new.perform
    cemetery = Facilities::NCAFacility.first
    expect(cemetery.address['mailing'].class).to eq(Hash)
    expect(cemetery.address['mailing'].empty?).to be true
  end
end
