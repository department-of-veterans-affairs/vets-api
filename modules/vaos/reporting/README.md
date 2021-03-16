
###

This is a guide for retrieving logs from AWS Cloudwatch with the included set of reporting scripts. These scripts are designed to write records to a local redis database from which they can be queired using redis-cli for easy access.

These steps assume a working local instance of vets-api.

##

  

1. Prerequisites

- Redis

	- https://redis.io/topics/quickstart or `brew install redis` with homebrew

- Python 2.7.*

	- https://docs.python-guide.org/

- awslogs npm module

	-  `brew install awslogs` with homebrew or `npm install -g awslogs` with npm

- Set up MFA and Devops repo
  
  - https://github.com/department-of-veterans-affairs/devops
##

  
  

2. Executing the scripts

  - Why use these scripts?
    - These scripts provide more informative reporting for triaging and diagnosing errors we see in cloudwatch. We want the capability to easily query for a specific request id or other attributes of interest and trace them through the backend stack. This allows us to more easily identify root-causes, and provide better data to downstream services like VAMF. Additionally, we may want to ask the data for records over a certain time range, and these scripts make it easy to do that. These scripts also scrub our data for PII before writing them to redis.
  
  - How are these scripts used?
    - `runner.rb` is the entry point to the querying process, and will result in a local redis cache being populated with log records from cloudwatch. The data in redis is namespaced according to filter pattern, timestamp, http verb, http status, and request id. This makes it easy to identify individual or sets of records that require further investigation. To kick off the script, it requires command line arguments for `filter_pattern` (ie. a valid Cloudwatch query), `start_date`, and `end_date`.
  
  - `runner.rb` examples:
    - querying for all log records with a message containing "VAOS service call" over the 24 hour period of 3/5/2021 to 3/6/2021:
      - `ruby runner.rb -f '{ ($.message = "VAOS service call*") }' -s '20210305000000' -e '20210306000000'`
    
    - querying for all log records with a specific request id over the 24 hour period of 3/5/2021 to 3/6/2021:
      - `ruby runner.rb -f '{ ($.named_tags.request_id = "36b9c9bc-6f7d-4f62-9740-934c6256cc6a") }' -s '20210305000000' -e '20210306000000'`
    
    - querying for all log records with a specific remote ip and a 200 status over the 24 hour period of 3/5/2021 to 3/6/2021:
      - `ruby runner.rb -f '{ ($.named_tags.remote_ip = "2601:642:4303:4ce0:4c7a:edae:e702:73a7") && ($.payload.status = "200") }' -s '20210305000000' -e '20210306000000'`

##  

3. Using the redis cache
  
  - Why redis?
    - Redis provides a lightweight interface and efficient storage that can easily be spun up on any user's local machine. It allows for well structured namespacing of data keys to provide organized storage and convenient retrieval of records. Additionally, redis allows for the inclusion of tty, so we can have healthy expiration dates on our records.
  
  - How is the data in redis organized?
    - Each entry in the redis cache represents a single log record from cloudwatch, and is stored with a key/value pair. The key is a namespaced scope in the form of `filter_pattern:timestamp:http_verb:http_status:request_id`, and the value is the entire JSON payload of that record.
  
  - How is the redis cache queried?
    - In the command line, run `redis-cli` to access the cache. From there, the value of a specific key can be returned using the `get` command, or sets of keys can be returned using the `keys` command. 
      
    - Examples:
      
      - return all entries in the cache:
        `keys *`
        
      - return all entries for booked cc appointments requests during 3/5/2021 with a 200 status:
        `keys booked-cc-appointments:20210305*:*:200:*`
        
      - return all entries for booked cc appointments requests during 3/5/2021 that had 500 level errors:
        `keys booked-cc-appointments:20210305*:*:50*:*`
        
      - return all entries with a specific request id:
        `keys *:*:*:*:36b9c9bc-6f7d-4f62-9740-934c6256cc6a`
      
      - return the JSON payload of a fully specified key:
        `get booked-cc-appointments:20210305022142:GET:200:36b9c9bc-6f7d-4f62-9740-934c6256cc6a`

        ```

        "{\"host\"=>\"14736c73c800\", \"application\"=>\"vets-api-server\", \"timestamp\"=>\"2021-03-05T02:21:42.064422Z\", \"level\"=>\"info\", \"level_index\"=>2, \"pid\"=>25, \"thread\"=>\"puma threadpool 003\", \"named_tags\"=>{\"request_id\"=>\"36b9c9bc-6f7d-4f62-9740-934c6256cc6a\", \"remote_ip\"=>\"2601:642:4303:4ce0:4c7a:edae:e702:73a7\", \"user_agent\"=>\"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.72 Safari/537.36\", \"ref\"=>\"5365da11ffc8bacbdebeea8ea2bc4b427d39b537\", \"csrf_token\"=>\"I14cJfTeSst/SLh2IIntQZe48m4ZHA5GL2XvV+n1jbdYnZReS9sX4RuXF4hz1Ukno7HTu5nQZP8gVxyGk5X5qQ==\"}, \"name\"=>\"Rails\", \"message\"=>\"VAOS service call succeeded!\", \"payload\"=>{\"jti\"=>\"765303ad-6f53-46d7-83bb-42ef212f2b9f\", \"status\"=>200, \"duration\"=>0.174332698, \"url\"=>\"(GET) https://internal-dsva-vagov-prod-fwdproxy-2075821597.us-gov-west-1.elb.amazonaws.com:4463/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling/patient/ICN/1012675143V171004/booked-cc-appointments?endDate=2022-04-03T07%3A00%3A00Z&pageSize=0&startDate=2021-03-04T08%3A00%3A00Z&useCache=false\"}}"

        ```
