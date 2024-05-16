# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'
require './modules/claims_api/app/services/claims_api/disability_compensation/pdf_generation_service'

describe ClaimsApi::DisabilityCompensation::PdfGenerationService do
  let(:pdf_generation_service) { ClaimsApi::DisabilityCompensation::PdfGenerationService.new }
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:claim_date) { (Time.zone.today - 1.day).to_s }
  let(:anticipated_separation_date) { 2.days.from_now.strftime('%m-%d-%Y') }
  let(:form_data) do
    temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', 'disability_compensation',
                           'form_526_json_api.json').read
    temp = JSON.parse(temp)
    attributes = temp['data']['attributes']
    attributes['claimDate'] = claim_date
    attributes['serviceInformation']['federalActivation']['anticipatedSeparationDate'] = anticipated_separation_date

    temp['data']['attributes']
  end
  let(:claim) do
    claim = create(:auto_established_claim, form_data:)
    claim.auth_headers = auth_headers
    claim.save
    claim
  end
  let(:middle_initial) { ' ' }
  let(:mapped_claim) {
{:data=>{:attributes=>{:claimProcessType=>"STANDARD_CLAIM_PROCESS", :changeOfAddress=>{:typeOfAddressChange=>"TEMPORARY", :newAddress=>{:country=>"US", :numberAndStreet=>"10 Peach St Unit 4 Room 1", :city=>"Atlanta", :state=>"GA", :zip=>"42220-9897"}, :effectiveDates=>{:start=>{:year=>"2023", :month=>"06", :day=>"04"}, :end=>{:year=>"2023", :month=>"12", :day=>"04"}}}, :serviceInformation=>{:alternateNames=>["john jacob", "johnny smith"], :servedInActiveCombatSince911=>"NO", :reservesNationalGuardService=>{:component=>"NATIONAL_GUARD", :obligationTermsOfService=>{:start=>{:year=>"2019", :month=>"06", :day=>"04"}, :end=>{:year=>"2020", :month=>"06", :day=>"04"}}, :unitName=>"National Guard Unit Name", :unitAddress=>"1243 pine court", :receivingInactiveDutyTrainingPay=>"YES", :unitPhoneNumber=>"555-555-5555"}, :federalActivation=>{:activationDate=>{:year=>"2023", :month=>"10", :day=>"01"}, :anticipatedSeparationDate=>{:year=>"2024", :month=>"10", :day=>"31"}}, :mostRecentActiveService=>{:start=>{:year=>"2008", :month=>"11", :day=>"14"}, :end=>{:year=>"2023", :month=>"10", :day=>"30"}}, :branchOfService=>{:branch=>"Public Health Service"}, :serviceComponent=>"ACTIVE", :prisonerOfWarConfinement=>{:confinementDates=>[{:start=>{:year=>"2018", :month=>"06", :day=>"04"}, :end=>{:year=>"2018", :month=>"07", :day=>"04"}}, {:start=>{:month=>"06", :year=>"2020"}, :end=>{:month=>"07", :year=>"2020"}}]}, :confinedAsPrisonerOfWar=>"YES", :servedInReservesOrNationalGuard=>"YES", :servedUnderAnotherName=>"YES", :activatedOnFederalOrders=>"YES"}, :servicePay=>{:receivingMilitaryRetiredPay=>"YES", :futureMilitaryRetiredPay=>"YES", :futureMilitaryRetiredPayExplanation=>"ABCDEFGHIJKLMNOPQRSTUVW", :militaryRetiredPay=>{:branchOfService=>{:branch=>"Army"}, :monthlyAmount=>840}, :retiredStatus=>"PERMANENT_DISABILITY_RETIRED_LIST", :favorMilitaryRetiredPay=>false, :receivedSeparationOrSeverancePay=>"YES", :separationSeverancePay=>{:datePaymentReceived=>{:year=>"2022", :month=>"03", :day=>"12"}, :branchOfService=>{:branch=>"Naval Academy"}, :preTaxAmountReceived=>379}, :favorTrainingPay=>true}, :claimCertificationAndSignature=>{:dateSigned=>{:year=>"2024", :month=>"05", :day=>"16"}, :signature=>"Jerry Brooks"}, :exposureInformation=>{:toxicExposure=>{:gulfWarHazardService=>{:servedInGulfWarHazardLocations=>"YES", :serviceDates=>{:start=>{:month=>"07", :year=>"2018"}, :end=>{:month=>"08", :year=>"2018"}}}, :herbicideHazardService=>{:servedInHerbicideHazardLocations=>"YES", :otherLocationsServed=>"ABCDEFGHIJKLM", :serviceDates=>{:start=>{:month=>"07", :year=>"2018"}, :end=>{:month=>"08", :year=>"2018"}}}, :additionalHazardExposures=>{:additionalExposures=>["ASBESTOS", "SHIPBOARD_HAZARD_AND_DEFENSE"], :specifyOtherExposures=>"Other exposure details", :exposureDates=>{:start=>{:month=>"07", :year=>"2018"}, :end=>{:month=>"08", :year=>"2018"}}}, :multipleExposures=>[{:hazardExposedTo=>"RADIATION", :exposureLocation=>"Guam", :exposureDates=>{:start=>{:month=>"12", :year=>"2012"}, :end=>{:month=>"07", :year=>"2013"}}}]}, :hasConditionsRelatedToToxicExposures=>"YES"}, :homelessInformation=>{:currentlyHomeless=>{:homelessSituationOptions=>"FLEEING_CURRENT_RESIDENCE", :otherDescription=>"ABCDEFGHIJKLM"}, :pointOfContact=>"john stewart", :pointOfContactNumber=>{:telephone=>"555-555-5555", :internationalTelephone=>"44-20-1234-5678"}, :areYouCurrentlyHomeless=>"YES"}, :identificationInformation=>{:serviceNumber=>"123456789", :mailingAddress=>{:city=>"Portland", :state=>"OR", :country=>"US", :numberAndStreet=>"1234 Couch Street Unit 4 Room 1", :zip=>"41726-1234"}, :emailAddress=>{:email=>"valid@somedomain.com", :agreeToEmailRelatedToClaim=>true}, :currentVaEmployee=>false, :vaFileNumber=>"796148937", :phoneNumber=>{:telephone=>"555-555-5555", :internationalTelephone=>"44-20-1234-5678"}, :name=>{:lastName=>"Brooks", :firstName=>"Jerry"}, :ssn=>"796-14-8937", :dateOfBirth=>{:month=>"09", :day=>"25", :year=>"1947"}}, :claimInformation=>{:disabilities=>[{:exposureOrEventOrInjury=>"EXPOSURE", :serviceRelevance=>"ABCDEFG", :approximateDate=>"03/11/2018", :disability=>"Traumatic Brain Injury"}, {:exposureOrEventOrInjury=>"EXPOSURE", :approximateDate=>"03/02/2018", :serviceRelevance=>"ABCDEFG", :disability=>"Cancer - Musculoskeletal - Elbow"}, {:exposureOrEventOrInjury=>"EXPOSURE", :approximateDate=>"2015", :serviceRelevance=>"ABCDEFG", :disability=>"Cancer - Musculoskeletal - Knee"}, {:exposureOrEventOrInjury=>"EXPOSURE", :serviceRelevance=>"ABCDEFGHIJKLMNOPQ", :approximateDate=>"03/12/2018", :disability=>"Post Traumatic Stress Disorder (PTSD) Combat - Mental Disorders secondary to: Traumatic Brain Injury"}], :treatments=>[{:treatmentDetails=>"Traumatic Brain Injury, Post Traumatic Stress Disorder (PTSD) Combat - Mental Disorders, Cancer - Musculoskeletal - Elbow - Center One, Decatur, GA", :dateOfTreatment=>{:month=>"03", :year=>"2009"}, :doNotHaveDate=>false}]}, :directDepositInformation=>{:noAccount=>false, :accountNumber=>"ABCDEF", :accountType=>"CHECKING", :financialInstitutionName=>"Chase", :routingNumber=>"123123123"}}}}
}

  describe '#generate' do
    it 'has a generate method that returns a claim id' do
      VCR.use_cassette('claims_api/pdf_client') do
        allow(pdf_generation_service).to receive(:generate_mapped_claim).with(claim, middle_initial).and_return(mapped_claim)

        expect(pdf_generation_service.send(:generate, claim.id, middle_initial)).to be_a(String)
      end
    end
  end
end
