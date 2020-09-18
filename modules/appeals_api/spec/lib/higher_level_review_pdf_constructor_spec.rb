# frozen_string_literal: true

require 'rails_helper'
require 'appeals_api/higher_level_review_pdf_constructor'

describe AppealsApi::HigherLevelReviewPdfConstructor do
  it 'builds the pdf options' do
    higher_level_review = create(:higher_level_review)
    constructor = AppealsApi::HigherLevelReviewPdfConstructor.new(higher_level_review.id)
    expect(constructor.pdf_options).to eq(valid_pdf_options)
  end

  it 'builds the extra pdf options' do
    higher_level_review = create(:extra_higher_level_review)
    constructor = AppealsApi::HigherLevelReviewPdfConstructor.new(higher_level_review.id)
    options = valid_pdf_options.merge(additional_page: "Issue: sleep apnea - Decision Date: 1900-01-07\n")
    expect(constructor.pdf_options).to eq(options)
  end

  it 'still builds the pdf options' do
    higher_level_review = create(:minimal_higher_level_review)
    constructor = AppealsApi::HigherLevelReviewPdfConstructor.new(higher_level_review.id)
    expect { constructor.pdf_options }.not_to raise_error
  end

  private

  # rubocop:disable Metrics/MethodLength
  def valid_pdf_options
    no_address_provided = AppealsApi::HigherLevelReview::NO_ADDRESS_PROVIDED_SENTENCE
    date_signed = AppealsApi::HigherLevelReview.new(form_data:
      { data: { attributes: { veteran: { timezone: 'America/Chicago' } } } }.as_json).date_signed
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
      'F[0].#subform[2].CurrentMailingAddress_NumberAndStreet[0]': no_address_provided,
      'F[0].#subform[2].CurrentMailingAddress_ApartmentOrUnitNumber[0]': '',
      'F[0].#subform[2].CurrentMailingAddress_City[0]': '',
      'F[0].#subform[2].CurrentMailingAddress_StateOrProvince[0]': '',
      'F[0].#subform[2].CurrentMailingAddress_Country[0]': '',
      'F[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]': '',
      'F[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]': '',
      'F[0].#subform[2].TELEPHONE[0]': '+34-555-800-1111 ex2',
      'F[0].#subform[2].EMAIL[0]': 'josie@example.com',
      'F[0].#subform[2].BenefitType[0]': 'Off',
      'F[0].#subform[2].BenefitType[1]': 'Off',
      'F[0].#subform[2].BenefitType[2]': 'Off',
      'F[0].#subform[2].BenefitType[3]': 'Off',
      'F[0].#subform[2].BenefitType[4]': 'Off',
      'F[0].#subform[2].BenefitType[5]': 'Off',
      'F[0].#subform[2].BenefitType[6]': 'Off',
      'F[0].#subform[2].BenefitType[7]': 'Off',
      'F[0].#subform[2].BenefitType[8]': 1,
      'F[0].#subform[2].HIGHERLEVELREVIEWCHECKBOX[0]': 1,
      'F[0].#subform[2].INFORMALCONFERENCECHECKBOX[0]': 1,
      'F[0].#subform[2].TIME8TO10AM[0]': 'Off',
      'F[0].#subform[2].TIME10TO1230PM[0]': 'Off',
      'F[0].#subform[2].TIME1230TO2PM[0]': 1,
      'F[0].#subform[2].TIME2TO430PM[0]': 1,
      'F[0].#subform[2].REPRESENTATIVENAMEANDTELEPHONENUMBER[0]': 'Helen Holly +6-555-800-1111 ext2',
      'F[0].#subform[3].SIGNATUREOFVETERANORCLAIMANT[0]': 'Jane Z Doe',
      'F[0].#subform[3].DateSigned[0]': date_signed,
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
