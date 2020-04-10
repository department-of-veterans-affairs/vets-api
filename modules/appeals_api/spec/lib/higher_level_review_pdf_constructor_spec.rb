# frozen_string_literal: true

require 'rails_helper'
require 'appeals_api/higher_level_review_pdf_constructor'

describe AppealsApi::HigherLevelReviewPdfConstructor do
  let(:auth_headers) do
    File.read(
      Rails.root.join('modules', 'appeals_api', 'spec', 'fixtures', 'higher_level_review_create_headers.json')
    )
  end
  let(:higher_level_review) { create_higher_level_review }

  it 'builds the veteran from the hlr data headers' do
    higher_level_review
    constructor = AppealsApi::HigherLevelReviewPdfConstructor.new(higher_level_review.id)
    expect(constructor.veteran.first_name).to eq('Heather')
    expect(constructor.veteran.middle_name).to eq('H')
    expect(constructor.veteran.last_name).to eq('Header')
    expect(constructor.veteran.ssn).to eq('123456789')
    expect(constructor.veteran.birth_date).to eq('1969-12-31')
    expect(constructor.veteran.va_file_number).to eq('2468')
    expect(constructor.veteran.service_number).to eq('1357')
    expect(constructor.veteran.insurance_policy_number).to eq('9876543210')
  end

  it 'builds the pdf options' do
    higher_level_review
    constructor = AppealsApi::HigherLevelReviewPdfConstructor.new(higher_level_review.id)
    expect(constructor.pdf_options).to eq(valid_pdf_options)
  end

  private

  def create_higher_level_review
    higher_level_review = create(:higher_level_review)
    higher_level_review.auth_headers = JSON.parse(auth_headers)
    higher_level_review.save
    higher_level_review
  end

  # rubocop:disable Metrics/MethodLength
  def valid_pdf_options
    {
      :"F[0].#subform[2].VeteransFirstName[0]" => 'Heather',
      :"F[0].#subform[2].VeteransMiddleInitial1[0]" => 'H',
      :"F[0].#subform[2].VeteransLastName[0]" => 'Header',
      :"F[0].#subform[2].SocialSecurityNumber_FirstThreeNumbers[0]" => '123',
      :"F[0].#subform[2].SocialSecurityNumber_SecondTwoNumbers[0]" => '34',
      :"F[0].#subform[2].SocialSecurityNumber_LastFourNumbers[0]" => '6789',
      :"F[0].#subform[2].DOBmonth[0]" => '12',
      :"F[0].#subform[2].DOBday[0]" => '31',
      :"F[0].#subform[2].DOByear[0]" => '1969',
      :"F[0].#subform[2].VAFileNumber[0]" => '2468',
      :"F[0].#subform[2].VeteransServiceNumber[0]" => '1357',
      :"F[0].#subform[2].InsurancePolicyNumber[0]" => '9876543210',
      :"F[0].#subform[2].CurrentMailingAddress_NumberAndStreet[0]" => '401 Kansas Avenue',
      :"F[0].#subform[2].CurrentMailingAddress_ApartmentOrUnitNumber[0]" => 'Unit #724',
      :"F[0].#subform[2].CurrentMailingAddress_City[0]" => 'Atchison',
      :"F[0].#subform[2].CurrentMailingAddress_StateOrProvince[0]" => 'KS',
      :"F[0].#subform[2].CurrentMailingAddress_Country[0]" => nil,
      :"F[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]" => '66002',
      :"F[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]" => nil,
      :"F[0].#subform[2].BenefitType[0]" => 9,
      :"F[0].#subform[2].BenefitType[1]" => 'Off',
      :"F[0].#subform[2].BenefitType[2]" => 'Off',
      :"F[0].#subform[2].BenefitType[3]" => 'Off',
      :"F[0].#subform[2].BenefitType[4]" => 'Off',
      :"F[0].#subform[2].BenefitType[5]" => 'Off',
      :"F[0].#subform[2].BenefitType[6]" => 'Off',
      :"F[0].#subform[2].BenefitType[7]" => 'Off',
      :"F[0].#subform[2].BenefitType[8]" => 'Off',
      :"F[0].#subform[2].HIGHERLEVELREVIEWCHECKBOX[0]" => 1,
      :"F[0].#subform[2].INFORMALCONFERENCECHECKBOX[0]" => 1,
      :"F[0].#subform[2].TIME8TO10AM[0]" => 'Off',
      :"F[0].#subform[2].TIME10TO1230PM[0]" => 'Off',
      :"F[0].#subform[2].TIME1230TO2PM[0]" => 1,
      :"F[0].#subform[2].TIME2TO430PM[0]" => 1,
      :"F[0].#subform[2].REPRESENTATIVENAMEANDTELEPHONENUMBER[0]" => nil,
      'F[0].#subform[3].SPECIFICISSUE1[1]' => 'tinnitus',
      'F[0].#subform[3].DateofDecision[5]' => '1900-01-01',
      'F[0].#subform[3].SPECIFICISSUE1[0]' => 'left knee',
      'F[0].#subform[3].DateofDecision[0]' => '1900-01-02',
      'F[0].#subform[3].SPECIFICISSUE3[0]' => 'right knee',
      'F[0].#subform[3].DateofDecision[1]' => '1900-01-03',
      'F[0].#subform[3].SPECIFICISSUE4[0]' => 'PTSD',
      'F[0].#subform[3].DateofDecision[2]' => '1900-01-04',
      'F[0].#subform[3].SPECIFICISSUE5[0]' => 'Traumatic Brain Injury',
      'F[0].#subform[3].DateofDecision[3]' => '1900-01-05',
      'F[0].#subform[3].SPECIFICISSUE6[0]' => 'right shoulder',
      'F[0].#subform[3].DateofDecision[4]' => '1900-01-06'
    }
  end
  # rubocop:enable Metrics/MethodLength
end
