# frozen_string_literal: true

require 'faraday'
require 'faraday_middleware'
require 'pp'
require 'faker'
require 'json'
require 'date'

class SetupTest

	A = Faker::Address
	I = Faker::Internet
	L = Faker::Lorem
	N = Faker::Name
	NUM = Faker::Number

  def initialize(env, user_token, times_to_run)
    @user_token = user_token
    @times_to_run = times_to_run
    @conn = Faraday.new(:url => "https://#{env}-api.vets.gov") do |faraday|
      faraday.response :json, content_type: /\bjson$/
      faraday.adapter Faraday.default_adapter
    end
  end

  def has_active_itf?
    response = @conn.get do |req|
      req.url '/v0/intent_to_file/compensation/active'
      req.headers['Authorization'] = "Token token=#{@user_token}"
    end
    puts response.status
    puts response.body

    response.body.dig('data', 'attributes', 'intent_to_file', 'status') == 'active'
  end

	def create_itf
		response = @conn.post do |req|
			req.url '/v0/intent_to_file/compensation'
			req.headers['Authorization'] = "Token token=#{@user_token}"
		end
    puts response.status
    puts response.body
	end

	def submit
		@times_to_run.times do
			response = @conn.post do |req|
				req.url '/v0/disability_compensation_form/submit'
				req.headers['Authorization'] = "Token token=#{@user_token}"
				pp submit_hash
				req.body = submit_hash.to_json
			end
      puts response.status
      puts response.body
		end
	end

	private
	# rubocop:disable all
	def submit_hash
		homeless = random_bool

		{
			"form526": {
				"veteran": {
					"emailAddress": I.email,
					"alternateEmailAddress": (I.email if random_bool),
					"mailingAddress": address,
					"forwardingAddress": (address.merge("effectiveDate": date) if random_bool),
          "primaryPhone": NUM.number(10),
					"homelessness": {
						"isHomeless": homeless,
						"pointOfContact": (if homeless
															 {
																 "pointOfContactName": N.name,
                                 "primaryPhone": NUM.number(10)
															 }
															end)
					}.reject{ |k,v| v.nil? },
					"serviceNumber": (NUM.number(9) if random_bool)
				}.reject{ |k,v| v.nil? },
				"attachments": (if random_bool
												[{
													"documentName": L.word,
													"dateUploaded": date,
													"attachmentType": L.word,
													"inflightDocumentId": NUM.number(10)
												}]
												end),
				"mililtaryPayments": (if random_bool
															{
																"payments": [{
																	"payType": pay_type,
																	"amount": NUM.number(5)
																}],
																"receiveCompensationInLieuOfRetired": random_bool
															}
														 end),
				"serviceInformation": {
					"servicePeriods": [{
						"serviceBranch": service_branch,
						"dateRange": date_range
					}],
					"reservesNationalGuardService": (if random_bool
																					 {
																						 "title10Activation": (if random_bool
																																	 {
																																		 "title10ActivationDate": date,
																																		 "anticipatedSeparationDate": date
																																	 }
																																	end),
																						 "obligationTermOfServiceDateRange": date_range,
																						 "unitName": L.word,
                                             "unitPhone": NUM.number(10),
																						 "inactiveDutyTrainingPay": (if random_bool
																																				 {
																																					 "waiveVABenefitsToRetainTrainingPay": random_bool
																																				 }
																																				 end)
																					 }.reject{ |k,v| v.nil? }
																					end),
					"servedInCombatZone": random_bool,
					"separationLocationName": (L.word if random_bool),
					"separationLocationCode": (L.word if random_bool),
					"alternateNames": ([N.name] if random_bool),
					"confinements": (if random_bool
													 [{
														 "confinementDateRange": date_range,
														 "verifiedIndicator": random_bool
													 }]
													end)
				}.reject{ |k,v| v.nil? },
				"disabilities": [{
					"name": L.word,
					"disabilityActionType": disability_action_type,
					"specialIssues": (if random_bool
														[{
															"code": special_issue_code,
															"name": L.word
														}]
													 end),
					"ratedDisabilityId": (L.word if random_bool),
					"ratingDecisionId": (L.word if random_bool),
					"diagnosticCode": (NUM.number(5) if random_bool),
					"classificationCode": (L.word if random_bool)
				}.reject{ |k,v| v.nil? }],
				"treatments": (if random_bool
												[{
													"treatmentCenterName": L.word,
													"treatmentDateRange": (date_range if random_bool),
													"treatmentCenterAddress": (address.slice("country", "city", "state") if random_bool),
													"treatmentCenterType": treatment_center_type
                        }.reject{ |k,v| v.nil? } ]
											end),
				"specialCircumstances": (if random_bool
																 [{
																	 "name": L.word,
																	 "code": L.word,
																	 "needed": random_bool
																 }]
																end),
				"standardClaim": random_bool,
				"claimantCertification": random_bool
      }.reject{ |k,v| v.nil? }
    }.reject{ |k,v| v.nil? }
	end
	# rubocop:enable all

	def random_bool
		[true, false].sample
	end

	def address
		{
			"addressLine1": A.street_address,
			"addressLine2": (A.secondary_address if random_bool),
			"city": A.city,
			"state": (A.state_abbr if random_bool),
			"zipCode": (A.zip if random_bool),
			"country": A.country
		}.reject{ |k,v| v.nil? }
	end

	# rubocop:disable all
	def date
		DateTime.parse(Faker::Date.between(Date.today - 365, Date.today).to_s)
	end

	def from_date
		DateTime.parse(Faker::Date.between(Date.today - (3 * 365), Date.today - 365).to_s)
	end
	# rubocop:enable all

	def date_range
		{
			"from": from_date,
			"to": date
		}
	end

	def pay_type
		%w[LONGEVITY TEMPORARY_DISABILITY_RETIRED_LIST PERMANENT_DISABILITY_RETIRED_LIST SEPARATION SEVERANCE].sample
	end

	def service_branch
		[
			'Air Force',
			'Air Force Reserve',
			'Air National Guard',
			'Army',
			'Army National Guard',
			'Army Reserve',
			'Coast Guard',
			'Coast Guard Reserve',
			'Marine Corps',
			'Marine Corps Reserve',
			'NOAA',
			'Navy',
			'Navy Reserve',
			'Public Health Service'
		].sample
	end

	def disability_action_type
		%w[NONE NEW SECONDARY INCREASE REOPEN].sample
	end

	def special_issue_code
		[
			'ALS',
			'AOIV',
			'AOOV',
			'ASB',
			'EHCL',
			'GW',
			'HEPC',
			'MG',
			'POW',
			'RDN',
			'SHAD',
			'TRM',
			'38USC1151',
			'PTSD/1',
			'PTSD/2',
			'PTSD/4)'
		].sample
	end

	def treatment_center_type
		%w[VA_MEDICAL_CENTER DOD_MTF].sample
	end
end
