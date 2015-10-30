require 'bundler/gem_tasks'

# https://github.com/bbatsov/rubocop#rake-integration
begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
  task default: :rubocop
rescue LoadError
  puts 'WARNING: Rubocop unavailable'
end

# https://www.relishapp.com/rspec/rspec-core/docs/command-line/rake-task
begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
  task default: :spec
rescue LoadError
  puts 'WARNING: Rspec unavailable'
end
