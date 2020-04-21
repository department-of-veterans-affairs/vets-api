# frozen_string_literal: true

require 'rails_helper'
require 'appeals_api/higher_level_review_pdf_constructor'

describe AppealsApi::HigherLevelReviewPdfConstructor do
  it 'builds the pdf options' do
    higher_level_review = create(:higher_level_review)
    constructor = AppealsApi::HigherLevelReviewPdfConstructor.new(higher_level_review.id)
    expect(constructor.pdf_options).to eq(valid_pdf_options)
  end

  private

  # rubocop:disable Metrics/MethodLength
  def valid_pdf_options
    {
      'F[0].#subform[2].VeteransFirstName[0]': 'Jane',
      'F[0].#subform[2].VeteransMiddleInitial1[0]': 'Z',
      'F[0].#subform[2].VeteransLastName[0]': 'Doe',
      'F[0].#subform[2].SocialSecurityNumber_FirstThreeNumbers[0]': '123',
      'F[0].#subform[2].SocialSecurityNumber_SecondTwoNumbers[0]': '45',
      'F[0].#subform[2].SocialSecurityNumber_LastFourNumbers[0]': '6789',
      'F[0].#subform[2].DOBmonth[0]': '12',
      'F[0].#subform[2].DOBday[0]': '31',
      'F[0].#subform[2].DOByear[0]': '1969',
      'F[0].#subform[2].VAFileNumber[0]': '987654321',
      'F[0].#subform[2].VeteransServiceNumber[0]': '876543210',
      'F[0].#subform[2].InsurancePolicyNumber[0]': '987654321123456789',
      'F[0].#subform[2].CurrentMailingAddress_NumberAndStreet[0]': '401 Kansas Avenue',
      'F[0].#subform[2].CurrentMailingAddress_ApartmentOrUnitNumber[0]': 'Apt 7',
      'F[0].#subform[2].CurrentMailingAddress_City[0]': 'Atchison',
      'F[0].#subform[2].CurrentMailingAddress_StateOrProvince[0]': 'KS',
      'F[0].#subform[2].CurrentMailingAddress_Country[0]': 'NL',
      'F[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]': '66002',
      'F[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]': '2410',
      'F[0].#subform[2].TELEPHONE[0]': '+34-555-800-1111 ex2',
      'F[0].#subform[2].EMAIL[0]': 'josie@example.com',
      'F[0].#subform[2].BenefitType[0]': 9,
      'F[0].#subform[2].BenefitType[1]': 'Off',
      'F[0].#subform[2].BenefitType[2]': 'Off',
      'F[0].#subform[2].BenefitType[3]': 'Off',
      'F[0].#subform[2].BenefitType[4]': 'Off',
      'F[0].#subform[2].BenefitType[5]': 'Off',
      'F[0].#subform[2].BenefitType[6]': 'Off',
      'F[0].#subform[2].BenefitType[7]': 'Off',
      'F[0].#subform[2].BenefitType[8]': 'Off',
      'F[0].#subform[2].HIGHERLEVELREVIEWCHECKBOX[0]': 1,
      'F[0].#subform[2].INFORMALCONFERENCECHECKBOX[0]': 1,
      'F[0].#subform[2].TIME8TO10AM[0]': 'Off',
      'F[0].#subform[2].TIME10TO1230PM[0]': 'Off',
      'F[0].#subform[2].TIME1230TO2PM[0]': 1,
      'F[0].#subform[2].TIME2TO430PM[0]': 1,
      'F[0].#subform[2].REPRESENTATIVENAMEANDTELEPHONENUMBER[0]': 'Helen Holly +6-555-800-1111 ext2',
      'F[0].#subform[3].SIGNATUREOFVETERANORCLAIMANT[0]': 'Jane Z Doe',
      'F[0].#subform[3].DateSigned[0]': Time.zone.now.strftime('%m/%d/%Y'),
      'F[0].#subform[3].SPECIFICISSUE1[1]': 'tinnitus',
      'F[0].#subform[3].DateofDecision[5]': '1900-01-01',
      'F[0].#subform[3].SPECIFICISSUE1[0]': 'left knee',
      'F[0].#subform[3].DateofDecision[0]': '1900-01-02',
      'F[0].#subform[3].SPECIFICISSUE3[0]': 'right knee',
      'F[0].#subform[3].DateofDecision[1]': '1900-01-03',
      'F[0].#subform[3].SPECIFICISSUE4[0]': 'PTSD',
      'F[0].#subform[3].DateofDecision[2]': '1900-01-04',
      'F[0].#subform[3].SPECIFICISSUE5[0]': 'Traumatic Brain Injury',
      'F[0].#subform[3].DateofDecision[3]': '1900-01-05',
      'F[0].#subform[3].SPECIFICISSUE6[0]': 'right shoulder',
      'F[0].#subform[3].DateofDecision[4]': '1900-01-06'
    }
  end
  # rubocop:enable Metrics/MethodLength
end
