# Vets.gov GI Bill Comparison Tool API
## API for exploring GI Bill education opportunities

##### Proxies the GI Data Service

Vets-API forwards all requests to the GI data service. It transforms the responses to ensure hypermedia links properly reflect the vets-api host.
Conforms to json:api media type.

##### Authentication

Consumers of this API are not authenticated or rate-limited. Requests are not encrypted. There is also no authentication or encryption between vets-api and the data service.

##### Available routes

| Resource  | Description | Params | Proxied Resource |
| --------- | ----------- | ------ | ------------- |
| GET /gi/institutions/search?  | Returns summarized institution search results.  | <ul><li><i>Several optional parameters for filtering the result set are enumerated below.</i></li></ul> | /v0/institutions |
| GET /gi/institutions/autocomplete?term=harv  | Returns a collection of institution names and facility codes matching the search term. | <ul><li>term: characters intended to match names or numeric facility codes <i>(Required)</i></li><li>returns a maximum of 6 results</li></ul> |  /v0/institutions/autocomplete |
| GET /gi/institutions/:facility_code  | Returns the profile attributes of an institution.  | <ul><li>facility_code: facility code of the institution<i>(Required)</i></li></ul> | /v0/institutions/:facility_code |
| GET /gi/calculator_constants  | Returns values required for benefit calculations.  | <ul></ul> | /v0/calculator/constants |

###### Institution Search Filter Params

| Query Param  | Description | Example Values |
| --------- | ----------- | ----- |
| name | Partially match institution names and cities. | duluth |
| type_name | Include institutions of a specific type. | ojt, private, foreign, correspondence, flight, for profit, public |
| state | Two-letter state abbreviation | MN |
| country |  | USA |
| caution | Excludes institutions with caution_flags when explicitly set to false. | true or false |
| student_veteran_group | Does this college/university have a student led student veterans group on campus? | true or false |
| yellow_ribbon_scholarship | Participation in the Yellow Ribbon Program. | true or false |
| principles_of_excellence | Complies with the Principles of Excellence. | true or false |
| eight_keys_to_veteran_success | Has voluntarily affirmed their support for the 8 Keys. | true or false |

##### Supported Formats

* JSON

##### Preview Mode

These optional parameters are used to specify which current or historical version of data is requested. All four endpoints support this feature.

| Query Param  | Description |
| --------- | ----------- |
| preview | exact version number requested |
| as_of | timestamp in ISO 8601 format |

##### Pagination

Only the search results endpoint supports pagination.
By default the first 10 items in the collection are returned.

| Query Param  | Description |
| --------- | ----------- |
| page | Which page of results is requested. ( _> 0, defaults to 1)|
| per_page | Number of results per page. ( _> 0 and ≤ 100_ ) |

##### Sorting

Sorting is not parameterized. Institution results are sorted by institution name.

##### Errors

| HTTP Code  | MHV Code | Description |
| -----------| -------- | ----------- |
| 404 | N/A | Resource not found |
| 503 | N/A | Internal error |
| 400 | 99 | Unknown error |

### Example responses

##### Search Results
```
{
  "data" : [
    {
      "id" : "27593",
      "type" : "institutions",
      "attributes" : {
        "city" : "STANFORD",
        "country" : "USA",
        "student_count" : 134,
        "eight_keys" : false,
        "student_veteran" : false,
        "name" : "STANFORD UNIVERSITY",
        "yr" : true,
        "type" : "private",
        "tuition_in_state" : 45195,
        "locale_type" : "suburban",
        "tuition_out_of_state" : 45195,
        "highest_degree" : 4,
        "books" : 1425,
        "bah" : 3600,
        "created_at" : "2017-01-21T20:06:48.219Z",
        "caution_flag" : null,
        "zip" : "94305",
        "caution_flag_reason" : null,
        "facility_code" : "31121005",
        "poe" : true,
        "updated_at" : "2017-01-21T20:06:48.219Z",
        "state" : "CA"
      },
      "links" : {
        "self" : "http://localhost:5000/v0/institutions/31121005",
        "website" : "http://www.stanford.edu/",
        "scorecard" : "https://collegescorecard.ed.gov/school/?243744-stanford-university"
      }
    }
  ],
  "meta" : {
    "version" : null
  },
  "links" : {
    "first" : "http://localhost:5000/v0/institutions?name=stanford&page=1&per_page=10&type_name=public",
    "prev" : null,
    "self" : "http://localhost:5000/v0/institutions?name=stanford&type_name=public",
    "last" : "http://localhost:5000/v0/institutions?name=stanford&page=1&per_page=10&type_name=public",
    "next" : null
  }
}
```

##### Profile
```
{
  "data": {
    "id": "12874",
    "type": "institutions",
    "attributes": {
      "name": "HARVARD UNIVERSITY",
      "facility_code": "31800121",
      "type": "private",
      "city": "CAMBRIDGE",
      "state": "MA",
      "zip": "02138",
      "country": "USA",
      "bah": 3045,
      "cross": "166027",
      "ope": "00215500",
      "highest_degree": 4,
      "locale_type": "city",
      "student_count": 285,
      "undergrad_enrollment": 7278,
      "yr": true,
      "student_veteran": false,
      "student_veteran_link": null,
      "poe": false,
      "eight_keys": false,
      "dodmou": true,
      "sec_702": false,
      "vet_success_name": null,
      "vet_success_email": null,
      "credit_for_mil_training": null,
      "vet_poc": "true",
      "student_vet_grp_ipeds": "true",
      "soc_member": null,
      "retention_rate_veteran_ba": 0,
      "retention_all_students_ba": 0.9706,
      "retention_rate_veteran_otb": 0.308,
      "retention_all_students_otb": null,
      "persistance_rate_veteran_ba": 1,
      "persistance_rate_veteran_otb": 0.385,
      "graduation_rate_veteran": null,
      "graduation_rate_all_students": 0.972133183,
      "transfer_out_rate_veteran": null,
      "transfer_out_rate_all_students": null,
      "salary_all_students": 87200,
      "repayment_rate_all_students": 0.840101523,
      "avg_stu_loan_debt": 6000,
      "calendar": "semesters",
      "tuition_in_state": 43938,
      "tuition_out_of_state": 43938,
      "books": 1000,
      "online_all": null,
      "p911_tuition_fees": 2676258.27,
      "p911_recipients": 157,
      "p911_yellow_ribbon": 914672.48,
      "p911_yr_recipients": 119,
      "accredited": true,
      "accreditation_type": "REGIONAL",
      "accreditation_status": null,
      "caution_flag": false,
      "caution_flag_reason": null,
      "complaints": {
        "facility_code": 0,
        "financial_by_fac_code": 0,
        "quality_by_fac_code": 0,
        "refund_by_fac_code": 0,
        "marketing_by_fac_code": 0,
        "accreditation_by_fac_code": 0,
        "degree_requirements_by_fac_code": 0,
        "student_loans_by_fac_code": 0,
        "grades_by_fac_code": 0,
        "credit_transfer_by_fac_code": 0,
        "credit_job_by_fac_code": 0,
        "job_by_fac_code": 0,
        "transcript_by_fac_code": 0,
        "other_by_fac_code": 0,
        "main_campus_roll_up": 3,
        "financial_by_ope_id_do_not_sum": 2,
        "quality_by_ope_id_do_not_sum": 0,
        "refund_by_ope_id_do_not_sum": 0,
        "marketing_by_ope_id_do_not_sum": 2,
        "accreditation_by_ope_id_do_not_sum": 0,
        "degree_requirements_by_ope_id_do_not_sum": 1,
        "student_loans_by_ope_id_do_not_sum": 0,
        "grades_by_ope_id_do_not_sum": 0,
        "credit_transfer_by_ope_id_do_not_sum": 0,
        "jobs_by_ope_id_do_not_sum": 0,
        "transcript_by_ope_id_do_not_sum": 0,
        "other_by_ope_id_do_not_sum": 2
      },
      "created_at": "2017-01-21T20:05:45.384Z",
      "updated_at": "2017-01-21T20:05:45.384Z"
    },
    "links": {
      "website": "http://www.harvard.edu",
      "scorecard": "https://collegescorecard.ed.gov/school/?166027-harvard-university",
      "vet_website_link": "http://universitysfs.harvard.edu/icb/icb.do?keyword=k90339&tabgroupid=icb.tabgroup152187",
      "self": "http://localhost:5000/v0/institutions/31800121"
    }
  },
  "meta": {
    "version": null
  }
}
```

#### Autocomplete
```
{
  "data": [
    {
      "id": 12874,
      "value": "31800121",
      "label": "HARVARD UNIVERSITY"
    },
    {
      "id": 12875,
      "value": "31802021",
      "label": "HARVARD UNIVERSITY-ARNOLD ARBORETUM"
    },
    {
      "id": 12876,
      "value": "31800221",
      "label": "HARVARD UNIVERSITY-EXTENSION"
    },
    {
      "id": 12877,
      "value": "20482615",
      "label": "HARVEST HEATING & AC"
    },
    {
      "id": 12878,
      "value": "31120569",
      "label": "HARVEST INTL THEOLOGICAL SEM"
    },
    {
      "id": 12879,
      "value": "30A05010",
      "label": "HARVEY-ENGELHARDT-METZ FUNERAL HOMES & CREMATION SERVICES"
    }
  ],
  "links": {
    "self": "http://localhost:5000/v0/institutions/autocomplete?term=harv"
  },
  "meta": {
    "version": null
  }
}
```

#### Constants
```
{
  "data": [
    {
      "id": 21,
      "name": "AVEGRADRATE",
      "float_value": 41.5,
      "string_value": null,
      "created_at": "2017-01-31T16:49:48.625Z",
      "updated_at": "2017-01-31T16:49:48.625Z"
    },
    {
      "id": 23,
      "name": "AVEREPAYMENTRATE",
      "float_value": 45.9,
      "string_value": null,
      "created_at": "2017-01-31T16:49:48.628Z",
      "updated_at": "2017-01-31T16:49:48.628Z"
    },
    {
      "id": 20,
      "name": "AVERETENTIONRATE",
      "float_value": 67.9,
      "string_value": null,
      "created_at": "2017-01-31T16:49:48.623Z",
      "updated_at": "2017-01-31T16:49:48.623Z"
    },
    {
      "id": 22,
      "name": "AVESALARY",
      "float_value": 33500,
      "string_value": null,
      "created_at": "2017-01-31T16:49:48.626Z",
      "updated_at": "2017-01-31T16:49:48.626Z"
    },
    {
      "id": 2,
      "name": "AVGBAH",
      "float_value": 1611,
      "string_value": null,
      "created_at": "2017-01-23T08:06:38.045Z",
      "updated_at": "2017-01-23T08:06:38.045Z"
    },
    {
      "id": 3,
      "name": "BSCAP",
      "float_value": 1000,
      "string_value": null,
      "created_at": "2017-01-31T16:49:48.587Z",
      "updated_at": "2017-01-31T16:49:48.587Z"
    },
    {
      "id": 4,
      "name": "BSOJTMONTH",
      "float_value": 83,
      "string_value": null,
      "created_at": "2017-01-31T16:49:48.591Z",
      "updated_at": "2017-01-31T16:49:48.591Z"
    },
    {
      "id": 6,
      "name": "CORRESPONDTFCAP",
      "float_value": 10671.35,
      "string_value": null,
      "created_at": "2017-01-31T16:49:48.596Z",
      "updated_at": "2017-01-31T16:49:48.596Z"
    },
    {
      "id": 10,
      "name": "DEARATE",
      "float_value": 1024,
      "string_value": null,
      "created_at": "2017-01-31T16:49:48.603Z",
      "updated_at": "2017-01-31T16:49:48.603Z"
    },
    {
      "id": 11,
      "name": "DEARATEOJT",
      "float_value": 747,
      "string_value": null,
      "created_at": "2017-01-31T16:49:48.605Z",
      "updated_at": "2017-01-31T16:49:48.605Z"
    },
    {
      "id": 5,
      "name": "FLTTFCAP",
      "float_value": 12554.54,
      "string_value": null,
      "created_at": "2017-01-31T16:49:48.594Z",
      "updated_at": "2017-01-31T16:49:48.594Z"
    },
    {
      "id": 8,
      "name": "MGIB2YRRATE",
      "float_value": 1509,
      "string_value": null,
      "created_at": "2017-01-31T16:49:48.599Z",
      "updated_at": "2017-01-31T16:49:48.599Z"
    },
    {
      "id": 7,
      "name": "MGIB3YRRATE",
      "float_value": 1857,
      "string_value": null,
      "created_at": "2017-01-31T16:49:48.598Z",
      "updated_at": "2017-01-31T16:49:48.598Z"
    },
    {
      "id": 9,
      "name": "SRRATE",
      "float_value": 369,
      "string_value": null,
      "created_at": "2017-01-31T16:49:48.601Z",
      "updated_at": "2017-01-31T16:49:48.601Z"
    },
    {
      "id": 1,
      "name": "TFCAP",
      "float_value": 21970.46,
      "string_value": null,
      "created_at": "2017-01-23T08:06:09.278Z",
      "updated_at": "2017-01-23T08:06:09.278Z"
    },
    {
      "id": 12,
      "name": "VRE0DEPRATE",
      "float_value": 605.44,
      "string_value": null,
      "created_at": "2017-01-31T16:49:48.608Z",
      "updated_at": "2017-01-31T16:49:48.608Z"
    },
    {
      "id": 16,
      "name": "VRE0DEPRATEOJT",
      "float_value": 529.36,
      "string_value": null,
      "created_at": "2017-01-31T16:49:48.615Z",
      "updated_at": "2017-01-31T16:49:48.615Z"
    },
    {
      "id": 13,
      "name": "VRE1DEPRATE",
      "float_value": 751,
      "string_value": null,
      "created_at": "2017-01-31T16:49:48.610Z",
      "updated_at": "2017-01-31T16:49:48.610Z"
    },
    {
      "id": 17,
      "name": "VRE1DEPRATEOJT",
      "float_value": 640.15,
      "string_value": null,
      "created_at": "2017-01-31T16:49:48.617Z",
      "updated_at": "2017-01-31T16:49:48.617Z"
    },
    {
      "id": 14,
      "name": "VRE2DEPRATE",
      "float_value": 885,
      "string_value": null,
      "created_at": "2017-01-31T16:49:48.612Z",
      "updated_at": "2017-01-31T16:49:48.612Z"
    },
    {
      "id": 18,
      "name": "VRE2DEPRATEOJT",
      "float_value": 737.77,
      "string_value": null,
      "created_at": "2017-01-31T16:49:48.619Z",
      "updated_at": "2017-01-31T16:49:48.619Z"
    },
    {
      "id": 15,
      "name": "VREINCRATE",
      "float_value": 64.5,
      "string_value": null,
      "created_at": "2017-01-31T16:49:48.614Z",
      "updated_at": "2017-01-31T16:49:48.614Z"
    },
    {
      "id": 19,
      "name": "VREINCRATEOJT",
      "float_value": 47.99,
      "string_value": null,
      "created_at": "2017-01-31T16:49:48.621Z",
      "updated_at": "2017-01-31T16:49:48.621Z"
    }
  ],
  "links": {
    "self": "http://localhost:5000/v0/calculator/constants"
  },
  "meta": {
    "version": null
  }
}
```
