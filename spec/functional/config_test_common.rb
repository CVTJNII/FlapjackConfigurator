require_relative '../spec_helper.rb'
require 'pathname'

# Common support methods for testing the gem
module TestCommon
  # Set up the test baseline
  def self.setup_test(before_when = :all)
    describe 'FlapjackConfigurator gem' do
      before before_when do
        @test_container = FlapjackTestContainer.new
        @test_diner = FlapjackTestDiner.new(@test_container)

        # Silence the logger
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::FATAL
      end

      yield(self)
    end
  end

  def self.load_config(name, subdir = nil)
    path_obj = Pathname.new('spec/functional/test_configs')
    path_obj += subdir if subdir
    path_obj += "#{name}.yaml"

    logger = Logger.new(STDOUT)
    logger.level = Logger::FATAL

    config = FlapjackConfigurator.load_config([path_obj.to_s], logger)
    fail "Failed to load test config from #{filename}" unless config
    return config
  end

  def self.setup_config_test(name)
    setup_test do |rspec_obj|
      rspec_obj.describe 'Config hash' do
        # Update passes
        { 'initial data'   => { subdir: 'initial', retval: true },
          'inital update'  => { subdir: 'initial', retval: false },
          'changed data'   => { subdir: 'changes', retval: true },
          'changed update' => { subdir: 'changes', retval: false }
        }.each do |test_name, test_data|
          test_config = TestCommon.load_config(name, test_data[:subdir])

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
