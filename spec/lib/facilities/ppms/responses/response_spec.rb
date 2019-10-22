# frozen_string_literal: true

require 'rails_helper'
require 'facilities/ppms/response'

describe Facilities::PPMS::Response do
  let(:caresites_response_body) do
    [
      {
        'Name' => '123 Main Street,Manassas,VA,20111',
        'Id' => '62bdd2b1-9dd1-e8111-12346324daqe4',
        'Latitude' => 38.8,
        'Longitude' => -76.6,
        'Street' => '123 Main Street'
      }
    ]
  end

  let(:provider_locator_body) do
    [
      {
        'Miles' => 7.47076307768083,
        'Minutes' => 11.5083333333333,
        'ProviderName' => 'DOCTOR PARTNERS OF NORTHERN VIRGINIA',
        'ProviderSpecialty' => 'Allergy & Immunology   ',
        'SpecialtyCode' => '207K00000X',
        'CareSite' => '4229 LAFAYETTE CENTER DR,UNIT 1760,CHANTILLY,VA,20151',
        'CareSiteAddress' => '123RANDOM ST,CHANTILLY,VA 20151',
        'CareSiteAddressCity' => 'MANASSAS',
        'CareSiteAddressStreeet' => '123 RANDOM STREET',
        'CareSiteAddressState' => 'VA',
        'CareSiteAddressZipCode' => '22030',
        'WorkHours' => nil,
        'ProviderGender' => 'NotSpecified',
        'ProviderNetwork' => 'Provider Agreement',
        'NetworkId' => 8,
        'ProviderAcceptingNewPatients' => false,
        'ProviderPrimaryCare' => false,
        'QualityRanking' => 0,
        'ProviderIdentifier' => '1700950045',
        'Latitude' => 45.5,
        'Longitude' => -122.5
      },
      {
        'Miles' => 59.2995756799325,
        'Minutes' => 60.97,
        'ProviderName' => 'DOCTOR PARTNERS OF SHENANDOAH VALLEY',
        'ProviderSpecialty' => 'Allergy & Immunology   ',
        'SpecialtyCode' => '207K00000X',
        'CareSite' => '1828 W PLAZA DR,WINCHESTER,VA,22601',
        'CareSiteAddress' => '1828 W PLAZA DR WINCHESTER,VA 22601',
        'CareSiteAddressCity' => 'MANASSAS',
        'CareSiteAddressStreet' => '123 RANDOM STREET',
        'CareSiteAddressState' => 'VA',
        'CareSiteAddressZipCode' => '22030',
        'CareSitePhoneNumber' => '(888) 444-1234',
        'WorkHours' => nil,
        'ProviderGender' => 'NotSpecified',
        'ProviderNetwork' => 'Provider Agreement',
        'NetworkId' => 8,
        'ProviderAcceptingNewPatients' => false,
        'ProviderPrimaryCare' => false,
        'QualityRanking' => 0,
        'ProviderIdentifier' => '1427435759',
        'Latitude' => 38.86787,
        'Longitude' => -78.17305
      },
      {
        'Miles' => 59.5528017001683,
        'Minutes' => 61.8516666666667,
        'ProviderName' => 'HEALTH CONSULTANTS OF VIRGINIA',
        'ProviderSpecialty' => 'Ophthalmology',
        'SpecialtyCode' => '207W00000X',
        'CareSite' => '420 W JUBAL EARLY DRIVE STE 203,WINCHESTER,VA,22601',
        'CareSiteAddress' => '420 W JUBAL EARLY DRIVE STE 203 WINCHESTER,VA 22601',
        'WorkHours' => nil,
        'ProviderGender' => 'NotSpecified',
        'ProviderNetwork' => 'Provider Agreement',
        'NetworkId' => 8,
        'ProviderAcceptingNewPatients' => false,
        'ProviderPrimaryCare' => false,
        'QualityRanking' => 0,
        'ProviderIdentifier' => '1114172319',
        'Latitude' => 39.16996,
        'Longitude' => -78.18052
      }
    ]
  end

  let(:services_response_body) do
    [
      {
        'Name' => 'Danzer,Hal  - Obstetrics & Gynecology    ',
        'AffiliationName' => 'TriWest',
        'ProviderName' => 'Danzer,Hal ',
        'ProviderAgreementName' => nil,
        'SpecialtyName' => 'Obstetrics & Gynecology   ',
        'ProviderSpecialtyName' => nil,
        'CareSiteLocationAddress' => 'SOUTHERN CALIF REPRODUCTIVE CTR MED GRP INC',
        'Longitude' => -122.5,
        'Latitude' => 45.8,
        'CareSiteAddressStreet' => '123 test street',
        'CareSiteAddressZipCode' => '11111',
        'CareSiteAddressCity' => 'Testville',
        'CareSiteAddressState' => 'VA',
        'CareSitePhoneNumber' => '(888) 444-1234',
        'OrganiztionGroupName' => nil,
        'DescriptionOfService' => nil,
        'Limitation' => nil
      },
      {
        'Name' => 'Danzer,Hal  - Obstetrics & Gynecology - Reproductive Endocrinology  ',
        'AffiliationName' => 'TriWest',
        'ProviderName' => 'Danzer,Hal ',
        'ProviderAgreementName' => nil,
        'SpecialtyName' => 'Obstetrics & Gynecology - Reproductive Endocrinology ',
        'ProviderSpecialtyName' => nil,
        'CareSiteLocationAddress' => 'SOUTHERN CALIF REPRODUCTIVE CTR MED GRP INC',
        'CareSitePhoneNumber' => nil,
        'OrganiztionGroupName' => nil,
        'DescriptionOfService' => nil,
        'Limitation' => nil
      }
    ]
  end

  let(:specialties_response_body) do
    [
      {
        'SpecialtyCode' => '101Y00000X', 'Name' => 'Counselor   ',
        'Grouping' => 'Behavioral Health & Social Service Providers',
        'Classification' => 'Counselor',
        'Specialization' => nil,
        'SpecialtyDescription' => "A provider who is trained and educated in the performance of behavior health services
         through interpersonal communications and analysis.
         Training and education at the specialty level usually requires a master’s
         degree and clinical experience and supervision for licensure or certification."
      },
      {
        'SpecialtyCode' => '101YA0400X',
        'Name' => 'Counselor - Addiction (Substance Use Disorder) ',
        'Grouping' => 'Behavioral Health & Social Service Providers',
        'Classification' => 'Counselor',
        'Specialization' => 'Addiction (Substance Use Disorder)', 'SpecialtyDescription' => 'Definition to come...'
      }
    ]
  end

  let(:response_body) do
    {
      'Id' => 0,
      'ProviderIdentifier' => '1427435759',
      'ProviderIdentifierType' => 'Npi',
      'Name' => 'DOCTOR PARTNERS',
      'ProviderType' => 'GroupPracticeOrAgency',
      'QualityRankingTotalScore' => 0,
      'QualityRankingLastUpdated' => nil,
      'MainPhone' => '(828) 555-1723',
      'Email' => nil,
      'Address' => "111 MAIN ST\r\nMANASSAS,VA 20111",
      'AddressStreet' => '111 MAIN ST',
      'AddressCity' => 'MANASSAS',
      'AddressStateProvince' => 'VA',
      'AddressPostalCode' => '20111',
      'AddressCounty' => nil,
      'AddressCountry' => nil,
      'ProviderStatusReason' => 'Active',
      'DoDAffiliation' => false,
      'VaAcademicAffiliate' => false,
      'PrimaryCarePhysician' => false,
      'HighPerformance' => false,
      'Fqhc' => false,
      'AccountableCareOrganization' => false,
      'IsAcceptingNewPatients' => false,
      'ProviderEthnicity' => 'Unknown',
      'ProviderGender' => 'Male',
      'Religion' => nil,
      'OrganizationId' => nil,
      'ServiceProviderType' => 'None',
      'SpecialInstruction' => nil,
      'OwnedCareSiteName' => nil,
      'OrganizationFax' => '(540) 665-0411',
      'OrganizationStatus' => 'Active',
      'IsExternal' => false,
      'InternalType' => '0',
      'LicensingJuristicion' => nil,
      'CanCreateHealthCareOrders' => false,
      'InternalAppointmentStatus' => 'FullTime',
      'ExternalHealthProviderType' => 'CommunityHospital',
      'OnLeie' => false,
      'ExternalInstitutionDeaNumber' => nil,
      'ExternalLeieCheckDate' => nil,
      'ValidationSource' => nil,
      'ContactMethod' => 'Any',
      'BulkEmails' => true,
      'BulkMails' => false,
      'Emails' => true,
      'Mails' => true,
      'PhoneCalls' => true,
      'Faxes' => true,
      'ModifiedOnDate' => '2018-08-02T04:27:10Z',
      'TerminationDate' => '0001-01-01T00:00:00Z',
      'ProviderSpecialties' => []
    }
  end

  let(:response) { Facilities::PPMS::Response.new(response_body, 200) }
  let(:new_provider) { response.new_provider }
  let(:provider_carsites_response) { Facilities::PPMS::Response.new(caresites_response_body, 200) }
  let(:provider_services_response) { Facilities::PPMS::Response.new(services_response_body, 200) }
  let(:provider_specialties_response) { Facilities::PPMS::Response.new(specialties_response_body, 200) }
  let(:bbox) { { bbox: [-79, 38, -77, 39] } }

  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:provider_locator_response) { Facilities::PPMS::Response.from_provider_locator(faraday_response, bbox) }

  describe 'getting data' do
    context 'with a successful response' do
      it 'has the proper response object attributes' do
        expect(response).not_to be(nil)
        expect(response.body).not_to be(nil)
        expect(response.get_body).not_to be(nil)
        expect(response.status).to eq(200)
      end

      it 'has the proper caresites identifiers' do
        expect(provider_carsites_response).not_to be(nil)
        expect(provider_carsites_response.body).not_to be(nil)
        expect(provider_carsites_response.status).to eq(200)
      end

      it 'has the proper provider services identifiers' do
        expect(provider_services_response).not_to be(nil)
        expect(provider_services_response.body).not_to be(nil)
        expect(provider_services_response.status).to eq(200)
      end

      it 'has the proper provider specialties identifiers' do
        expect(provider_specialties_response).not_to be(nil)
        expect(provider_specialties_response.body).not_to be(nil)
        expect(provider_specialties_response.status).to eq(200)
      end

      it 'has the proper provider locator identifiers' do
        allow(faraday_response).to receive(:body) { provider_locator_body }
        allow(faraday_response).to receive(:status).and_return(200)
        expect(faraday_response.body.length).to be > 0
        expect(faraday_response.body[0]['Latitude']).to be > 45
        expect(faraday_response.body[0]['Longitude']).to be < -122
      end

      it 'has the proper provider_info identifiers' do
        expect(new_provider['ProviderIdentifier']).not_to be(nil)
        expect(new_provider['MainPhone']).not_to be(nil)
        expect(new_provider['Name']).not_to be(nil)
      end
    end
  end
end
