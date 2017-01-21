# Vets.gov GI Bill Comparison Tool API

### API for obtaining GI Bill eligiblity and maximum benefits

Short description goes here.

##### Available routes

| Resource  | Description | Params |
| --------- | ----------- | ------ |
| GET /gi/institutions?  | Returns summarized institution search results.  | <ul><li><i>Several other optional parameters for filtering the result set enumerated below. [Institution Search Filter Params](#institutionSearchFilterParams)</i></li></ul> |
| GET /gi/institutions/autocomplete?term=&limit=6  | Returns a collection of institution names and facility codes matching the search term. | <ul><li>term: characters intended to match names or numeric facility codes <i>(Required)</i></li><li>limit: maximum number of results between 1 and 25 <i>(Optional, default is 6)</i></li></ul> |
| GET /gi/institutions/:facility_code  | Returns the profile attributes of an institution.  | <ul><li>facility_code: numeric facility code of the institution<i>(Required)</i></li></ul> |
| GET /gi/constants  | Returns constants required for benefit calculations.  | <ul></ul> |

###### Institution Search Filter Params

| Query Param  | Description |
| --------- | ----------- |
| institution_search | search term (facility code or name) |
| type_name | `school` or `employer` or `all` |
| state | two-letter state abbreviation |
| country |  |
| student_veteran_group |  |
| yellow_ribbon_scholarship |  |
| principles_of_excellence |  |
| f8_keys_to_veteran_success |  |
| types |  |

##### Supported Formats

* JSON

##### Preview Mode

| Query Param  | Description |
| --------- | ----------- |
| preview | exact version number requested |
| as_of | timestamp in ISO 8601 format |

##### Pagination

GET requests that return more than one result will be paginated.  The default pagination returns the first 10 items in the collection.

| Query Param  | Description |
| --------- | ----------- |
| page | Which page of results is requested. ( _> 0, defaults to 1)|
| per_page | Number of results per page. ( _> 0 and ≤ 100_ ) |

Pagination uses the [will_paginate](https://github.com/mislav/will_paginate) library.

##### Sorting

Sorting is not parameterized and is always done blah blah blah.

##### Errors

| HTTP Code  | MHV Code | Description |
| -----------| -------- | ----------- |
| 404 | N/A |Resource not found |
| 503 | N/A |Internal error |
| 400 | 99 | Unknown error |
| 400 | 101 | MHV application authentication failed |

##### Explanation of Attributes and Acronyms

| 	| Explanation |
| -------- | ----------- |
| attr | desc |
