# frozen_string_literal: true
# desc "Explaining what the task does"
# task :appeals do
#   # Task goes here
# end

task appeals_api_hlr_pdf: :environment do
  require 'appeals_api/hlr_pdf_constructor'

  higher_level_review = AppealsApi::HigherLevelReviewSubmission.last
  pdf_constructor = AppealsApi::HlrPdfConstructor.new(higher_level_review.id)
  pdf_constructor.fill_pdf
  # form_data = higher_level_review.form_data['data']['attributes']
  # included = higher_level_review.form_data['included']
  # auth_headers = higher_level_review.auth_headers
  # veteran = OpenStruct.new(
  #   first_name: auth_headers['X-VA-First-Name'],
  #   middle_name: auth_headers['X-VA-Middle-Initial'],
  #   last_name: auth_headers['X-VA-Last-Name'],
  #   ssn: auth_headers['X-VA-SSN'],
  #   birth_date: auth_headers['X-VA-Birth-Date'],
  #   address_line_1: form_data.dig('veteran', 'address', 'addressLine1'),
  #   address_line_2: form_data.dig('veteran', 'address', 'addressLine2'),
  #   city: form_data.dig('veteran', 'address', 'city'),
  #   state: form_data.dig('veteran', 'address', 'stateCode'),
  #   country: form_data.dig('veteran', 'address', 'country'),
  #   zip: form_data.dig('veteran', 'address', 'zipCode'),
  #   zip_last_4: form_data.dig('veteran', 'address', 'zip_last_4'),
  #   benefit_type: form_data['benefitType'],
  #   same_office: form_data['sameOffice'],
  #   informal_conference: form_data['informalConference'],
  #   conference_times: form_data['informalConferenceTimes'],
  #   issues: included
  # )
  # pdf_constructor = AppealsApi::HlrPdfConstructor.new(veteran)
  # pdf_constructor.fill_pdf
end
