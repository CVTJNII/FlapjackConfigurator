require_relative 'docker_test_wrapper.rb'

require 'simplecov'
require 'bundler/setup'

Bundler.setup

SimpleCov.start
require 'flapjack_configurator'
