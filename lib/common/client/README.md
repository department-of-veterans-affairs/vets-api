## Common::Client

Common::Client is a library intended to help make writing backend service layers easier.

It provides a number of helpful middlewares for converting JSON keys to and from camelCase
to snake_case, handling errors, and handling multipart requests.

Despite having a configuration class, it emphasizes convention vs configuration with helpful modules and patterns for organizing commonly used API features such as token based sessions. It also features a custom backend_service_error exception ideal for various serialization and rendering.

## Purpose

To bring some degree of convention vs configuration towards building backend service integrations that is composable yet easy to implement.

Having a single client class for each backend integration quickly becomes a headache to maintain and common patterns are easily siloed off into separate libraries. This library
attempts to move the cruft of API cient creation into composable classes to bring something
degree of uniformity towards backend integrations within a project.

## Usage

In a future iteration, there will be a rails generator to help with building the skeleton for a new service integration.

For now, to begin, create a new directory under lib with a short acronym describing the service you would like to integrate.

Any custom middleware you create would then ideally go into a middleware folder within this
path. In addition you will need at least 2 additional classes.

1. Common::Client::Configuration- the configuration class is where you describe the base_path, timeout settings, and the Faraday::Connection for your client. You can customize every single aspect of the configuration to be used. Each client when initialized will fetch a new instance of Faraday::Connection from configuration and memoize the connection.

2. Common::Client::Base - the client implements a perform method that once you've built your subclass is all you should need for making HTTP requests.

3. Common::Client::Session (OPTIONAL) - the session class is available for implementing a token based session management mechanism. This class provides redis backed token management. An example concerns is provided as a mixin for working with various MHV services. One can write something similar for other services as needed.
