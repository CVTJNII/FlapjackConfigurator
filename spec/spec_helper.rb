require_relative 'docker_test_wrapper.rb'

require 'simplecov'
require 'bundler/setup'

Bundler.setup

#RSpec.configure do |c|
#  c.filter_run(focus: true)
#  c.run_all_when_everything_filtered = true
#end

SimpleCov.start
require 'flapjack_configurator'
