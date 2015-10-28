lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'flapjack_configurator/version'

Gem::Specification.new do |gem|
  gem.authors       = [ 'Tom Noonan II' ]
  gem.email         = 'thomas.noonan@corvisa.com'
  gem.description   = 'FlapjackConfigurator loads a user specified config from YAML files and loads them idempotently into Flapjack via the Flapjack API'
  gem.summary       = 'Flapjack configuration tool'
#  gem.homepage      = ''
  gem.license       = 'Apache License, Version 2'

  gem.files         = `git ls-files`.split($\) - ['Gemfile.lock']
  gem.executables   = gem.files.grep(%r{^bin/}).map{|f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = 'flapjack_configurator'
  gem.require_paths = ['lib']
  gem.version       = FlapjackConfigurator::VERSION

  gem.add_dependency 'flapjack-diner', '~>1.3'
  gem.add_dependency 'ruby_deep_clone', '~>0.6'
  gem.add_dependency 'deep_merge', '~>1.0'

  gem.add_development_dependency 'bundler', '~> 1.7'
  gem.add_development_dependency 'rake', '~> 10.0'
end
