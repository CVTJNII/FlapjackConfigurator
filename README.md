Flapjack Configurator
=====================

[![Gem Version](https://badge.fury.io/rb/flapjack_configurator.svg)](https://badge.fury.io/rb/flapjack_configurator)

This gem provides a idempotent, file based fonfigurator for [Flapjack](http://flapjack.io)

Configuration
-------------

The general config form is:

```yaml
# Example/Demo Flapjack setup file

baseline_options:
  notification_media:
    # Baseline Pagerduty creds
    # Pagerduty setup takes the domain, a API token to poll for acks, and a service key unique to the Pagerduty service
    # Define the (common) domain id and API token here
    # Currently only one PD instance is supported to keep the config handling easy. (/lazy)
    pagerduty:
      subdomain: foocorp
      token: PagerDutyAPIToken

# Contacts!
contacts:
  TestUser:
    # Details is a direct map to the Flapjack API arguments (except notification related fields)
    # http://flapjack.io/docs/1.0/jsonapi/#create-contacts
    details:
      first_name: Test
      last_name: User
      # Email is required but is only used here for documentation
      email: test.user@example.com
      timezone: MST7MDT

    notification_media:
      defaults:
        # Re-notify every 30 minutes
        interval: 1800
        rollup_threshold: 3

      # Only one of each is allowed in Flapjack 1.x :(
      pagerduty:
        service_key: PagerDutyServiceKey

      email:
        address: test.user@example.com

      jabber:
        address: room@conf.hipchat.com

    notification_rules:
      default:
        warning_media:
          - jabber
          - email
        critical_media:
          - pagerduty
          - jabber
          - email

    # Entities: A list of entities to associate with the contact
    # Priority ordering is:
    #  1: Exact entities
    #  2: Blacklist entities
    #  3: Blacklist regex
    #  4: Entities regex
    #
    # If entities/default is true the contact will be associated with all entities which would otherwise not be associated with any contact.
    entities:
      default: false
      exact:
        - foo-app-1
      regex:
        - "datagen-[0-9]+"
    entities_blacklist:
      exact:
        - datagen-2
      regex:
        - "datagen-[78]"
```

Most (but not all) of the options are passed through directly to the API (This is logged at debug level).
notification_media and notification_rules are merged down with the per contact rule with the highest precidence, contact defaults, and then baseline_options.
The key must be present in the contact to merge to prevent partial settings from being built off defaults.
Complete configs at the baseline_option level with automatic inheritance is not currently supported.

Use
===

WARNING: Passwords/API tokens will be logged at debug log level!

Command Line
------------

```
$ flapjack_configurator -h
Usage: flapjack_configurator [options]

Specific options:
    -u, --apiurl URL                 Flapjack API URL
    -v, --verbosity [level]          Set Verbosity, level corresponds to Ruby logger levels (0: debug, 3: error)
    -f, --files file1,file2,file3    List of YAML config files to load, increasing precidence
    -h, --help                       Show this message
        --version                    Show version
```

Files is a comma-separated list of yaml files which are merged together to form the configuration.
API URL should be of the form "http://${hostname}:${port}"

Gem
---

```
require 'flapjack_configurator'

FlapjackConfigurator.configure_flapjack(config, api_base_url, logger)
```

### configure_flapjack method:

Loads the specificed into config

- Arguments:
  - config (Hash): Configuration hash to apply
  - api_base_url (String)(Default: http://127.0.0.1:3081): Flapjack API URL string to connect to
  - logger (Logger)(Default: Logger.new(STDOUT)): Logger class to log to
  - enable_all_entity (Boolean)(Default: true): Add the ALL magic entity if it doesn't exist
- Return value: Boolean: true if changes were applied, false otherwise

### load_config method:

Loads and merges a list of yaml config files into a config passable to configure_flapjack

- Arguments:
  - file_list (List): List of files to load
  - logger (Logger)(Default: Logger.new(STDOUT)): Logger class to log to
- Return value: Hash: Config loaded from the specified files

Testing
=======

The Rubocop and Rspec coverage are part of the default rake task.
Tests spin up a Flapjack container in Docker and interact with its API, no mocks are used.
As such a running Docker daemon is required for tests.

Authors
=======

- Tom Noonan <thomas.noonan@corvisa.com>
