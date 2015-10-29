require_relative '../spec_helper.rb'
require 'yaml'

module ConfigTestCommon
  def self.setup_config_test(name)
    describe 'FlapjackConfigurator gem' do
      before :all do
        @test_container = FlapjackTestContainer.new()
        @test_diner = FlapjackTestDiner.new(@test_container)

        # Silence the logger
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::FATAL
      end

      describe 'Config hash' do
        # Update passes
        { 'initial data'   => { subdir: 'initial', retval: true },
          'inital update'  => { subdir: 'initial', retval: false },
          'changed data'   => { subdir: 'changes', retval: true },
          'changed update' => { subdir: 'changes', retval: false }
        }.each do |test_name, test_data|
          filename = "spec/functional/test_configs/#{test_data[:subdir]}/#{name}.yaml"
          test_config = YAML.load_file(filename)
          fail "Failed to load test config from #{filename}" unless test_config

          describe "Contact #{name} #{test_name}" do
            before :all do
              @config_output = FlapjackConfigurator.configure_flapjack(test_config, @test_container.api_url, @logger, true)
            end

            it 'returns true if changes are made' do
              expect(@config_output).to eq(test_data[:retval])
            end

	    yield(self, test_config)
          end
        end
      end
    end
  end
end
