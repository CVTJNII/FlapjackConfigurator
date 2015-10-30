require 'bundler/gem_tasks'

# https://github.com/bbatsov/rubocop#rake-integration
require 'rubocop/rake_task'
RuboCop::RakeTask.new
task default: :rubocop

# https://www.relishapp.com/rspec/rspec-core/docs/command-line/rake-task
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)
task default: :spec
