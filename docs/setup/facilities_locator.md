### Facilities Locator Setup

For the current maps.va.gov endpoint, you will need to add the VA internal root
CA certificate to your trusted certificates. With `homebrew` this is typically
done by appending the exported/downloaded certificate to
`<HOMEBREW_DIR>/etc/openssl/cert.pem`.

#### Retrieving Mental Health Phone Numbers

To retrieve mental health phone numbers, please run this rake job:

`bundle exec rake jobs:pull_facility_mental_health_phone`