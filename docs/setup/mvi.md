## MVI Service

The Master Veteran Index service retrieves and updates a veteran's 'golden record'.
To configure `vets-api` for use with MVI, configure `config/settings.local.yml`
with the settings given to you by devops or your team. For example,

```
# config/settings.local.yml
mvi:
  url: ...
```

Since that URL is only accessible over the VA VPN a mock service is included in the project.
To enable it, add this to `config/settings.local.yml`:

```
mvi:
  mock: true
```

Endpoint response values can be set by copying `mock_mvi_responses.yml.example`
to `mock_mvi_responses.yml`. For the `find_candidate` endpoint you can return
different responses based on SSN:

```
find_candidate:
  555443333:
    birth_date: '19800101'
    edipi: '1234^NI^200DOD^USDOD^A'
    family_name: 'Smith'
    gender: 'M'
    given_names: ['John', 'William']
    icn: '1000123456V123456^NI^200M^USVHA^P'
    mhv_id: '123456^PI^200MHV^USVHA^A'
    ssn: '555443333'
    status: 'active'
  111223333:
    # another mock response hash here...
```
