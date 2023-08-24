require 'awesome_print'
require 'erb'
require 'faraday'
# require 'faraday_middleware'  <-- might need this if you get a Faraday error
require 'json'
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'vcr_cassettes'
  config.hook_into :webmock
  config.allow_http_connections_when_no_cassette = true
end

# Profile Endpoint
url = 'https://localhost:4000/profile-service/profile/v3'

oid   = '2.16.840.1.113883.3.42.10001.100001.12'
edipi = '1005127153'
aaid  = '^NI^200DOD^USDOD'

path = oid + "/" + ERB::Util.url_encode("#{edipi}#{aaid}")

options = {:verify => false}
conn = Faraday.new(url, ssl: options) do | builder |
  builder.request :json
  # builder.adapter Faraday.default_adapter  <-- might need this if you get a Faraday error
end

body = { bios: [ { bioPath: 'militaryPerson.militarySummary'  } ] }

VCR.use_cassette("miliary_service_200_#{Time.now.getutc}") do
  response = conn.post(path) do |req|
    req.body = body.to_json
  end

  ap "Status: #{response.status}"
  ap JSON.parse(response.body)
end


# Here are some more bios available...
# { "bioPath": "militaryPerson.adminDecisions" },
# { "bioPath": "militaryPerson.adminEpisodes" },
# { "bioPath": "militaryPerson.dentalIndicators" },
# { "bioPath": "militaryPerson.militaryOccupations", "parameters": { "scope": "all" }  },
# { "bioPath": "militaryPerson.militaryServiceHistory", "parameters": { "scope": "latest"  }  },
# { "bioPath": "militaryPerson.militarySummary" },
# { "bioPath": "militaryPerson.militarySummary.customerType.dodServiceSummary"  },
# { "bioPath": "militaryPerson.payGradeRanks", "parameters": { "scope": "highest"  } },
# { "bioPath": "militaryPerson.prisonerOfWars" },
# { "bioPath": "militaryPerson.transferOfEligibility" },
# { "bioPath": "militaryPerson.retirements" },
# { "bioPath": "militaryPerson.separationPays" },
# { "bioPath": "militaryPerson.retirementPays" },
# { "bioPath": "militaryPerson.combatPays" },
# { "bioPath": "militaryPerson.unitAssignments"  }