## Common::Exceptions

Common::Exceptions is a library intended to help make exception classes serializable.

It is particularly suited for helping to render JSONAPI style errors. It is divided into
two types, `internal` exceptions that are raised within the various models and controllers
of your Rails application and `external` exceptions that are raised by backend services.

The external exceptions will need to be setup properly using custom middlewares.

## Purpose

To be able to jump out of the call stack and render an error response as part of an
orchestration layer for various backend service integrations.

## Usage

Each exception class has a unique way of being invoked. To customize the messages for these
error classes an i18n locales file is available.
