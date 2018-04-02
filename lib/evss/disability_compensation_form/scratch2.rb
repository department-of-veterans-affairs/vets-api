require 'faraday'
require 'date'
require 'json'

headers = {
  "va_eauth_csid" => "DSLogon", 
  "va_eauth_authenticationmethod" => "DSLogon", 
  "va_eauth_pnidtype" => "SSN", 
  "va_eauth_assurancelevel" => "3", 
  "va_eauth_firstName" => "Mark", 
  "va_eauth_lastName" => "Webb", 
  "va_eauth_issueinstant" => DateTime.now.iso8601, 
  "va_eauth_dodedipnid" => "1013590059", 
  "va_eauth_birlsfilenumber" => 796068948,
  "va_eauth_pid" => "13367440", 
  "va_eauth_pnid" => "796104437", 
  "va_eauth_birthdate" => "1950-10-04T00:00:00+00:00", 
  "va_eauth_authorization" => "{\"authorizationResponse\":{\"status\":\"VETERAN\",\"idType\":\"SSN\",\"id\":\"796104437\",\"edi\":\"1013590059\",\"firstName\":\"Mark\",\"lastName\":\"Webb\",\"birthDate\":\"1950-10-04T00:00:00+00:00\",\"gender\":\"M\"}}",
  "va_eauth_gender" => "FEMALE",
  "Content-Type" => "application/json", 
}

conn = Faraday.new(
  "https://csraciapp6.evss.srarad.com/wss-form526-services-web/rest/form526/v1", ssl: { verify: false }
) do |faraday|
  faraday.adapter :httpclient
end

body = {
  "form526": {
    "veteran": {
      "emailAddress": "string",
      "alternateEmailAddress": "string",
      "mailingAddress": {
        "addressLine1": "string",
        "addressLine2": "string",
        "addressLine3": "string",
        "city": "string",
        "state": "IL",
        "zipFirstFive": "11111",
        "zipLastFour": "1111",
        "country": "string",
        "militaryStateCode": "AA",
        "militaryPostOfficeTypeCode": "APO",
        "type": "DOMESTIC"
      },
      "forwardingAddress": {
        "addressLine1": "string",
        "addressLine2": "string",
        "addressLine3": "string",
        "city": "string",
        "state": "IL",
        "zipFirstFive": "11111",
        "zipLastFour": "1111",
        "country": "string",
        "militaryStateCode": "AA",
        "militaryPostOfficeTypeCode": "APO",
        "type": "DOMESTIC",
        "effectiveDate": "2018-03-29T18:50:03.014Z"
      },
      "primaryPhone": {
        "areaCode": "555",
        "phoneNumber": "5555555"
      },
      "homelessness": {
        "hasPointOfContact": false,
      },
      "serviceNumber": "string"
    },
    "attachments": [],
    "militaryPayments": {
      "payments": [],
      "receiveCompensationInLieuOfRetired": false,
      "receivingInactiveDutyTrainingPay": false,
      "waveBenifitsToRecInactDutyTraiPay": false
    },
    "directDeposit": {
      "accountType": "CHECKING",
      "accountNumber": "1234",
      "bankName": "string",
      "routingNumber": "123456789"
    },
    "serviceInformation": {
      "servicePeriods": [
        {
          "serviceBranch": "string",
          "activeDutyBeginDate": "2018-03-29T18:50:03.015Z",
          "activeDutyEndDate": "2018-03-29T18:50:03.015Z"
        }
      ],
      "reservesNationalGuardService": {
        "title10Activation": {
          "title10ActivationDate": "2018-03-29T18:50:03.015Z",
          "anticipatedSeparationDate": "2018-03-29T18:50:03.015Z"
        },
        "obligationTermOfServiceFromDate": "2018-03-29T18:50:03.015Z",
        "obligationTermOfServiceToDate": "2018-03-29T18:50:03.015Z",
        "unitName": "string",
        "unitPhone": {
          "areaCode": "555",
          "phoneNumber": "5555555"
        }
      },
      "servedInCombatZone": true,
      "separationLocationName": "OTHER",
      "separationLocationCode": "SOME VALUE",
      "alternateNames": [
        {
          "firstName": "string",
          "middleName": "string",
          "lastName": "string"
        }
      ],
      "confinements": [
        {
          "confinementBeginDate": "2018-03-29T18:50:03.015Z",
          "confinementEndDate": "2018-03-29T18:50:03.015Z",
          "verifiedIndicator": false
        }
      ]
    },
    "disabilities": [
      {
        "diagnosticText": "Diabetes mellitus",
        "disabilityActionType": "INCREASE",
        "decisionCode": "SVCCONNCTED",
        "specialIssues": [
          {
            "code": "TRM",
            "name": "Personal Trauma PTSD"
          }
        ],
        "ratedDisabilityId": "0",
        "ratingDecisionId": 63655,
        "diagnosticCode": 5235,
        "secondaryDisabilities": [
          {
            "decisionCode": "",
            "ratedDisabilityId": "",
            "diagnosticText": "string",
            "disabilityActionType": "NONE"
          }
        ]
      }
    ],
    "treatments": [],
    "specialCircumstances": [
      {
        "name": "string",
        "code": "string",
        "needed": false
      }
    ]
  }
}

response = conn.post do |req|
  req.url 'submit'
  req.headers = headers
  req.body = body.to_json
end

puts response.status
puts response.body
