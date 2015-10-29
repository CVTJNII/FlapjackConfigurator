require_relative '../spec_helper.rb'

describe 'FlapjackConfigurator gem' do
  before :each do
    @test_container = FlapjackTestContainer.new()
    @test_diner = FlapjackTestDiner.new(@test_container)

    @dummy_config = { 'contacts' => {} }
    
    # Silence the logger
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::FATAL
  end

  describe 'All Magic Entity' do
    it 'is not created when enable_all_entity is false' do
      ret_val = FlapjackConfigurator.configure_flapjack(@dummy_config, @test_container.api_url, @logger, false)
      expect(ret_val).to eq(false)
      expect(@test_diner.diner.entities('ALL')).to be_nil
    end

    it 'is created when enable_all_entity is true' do
      ret_val = FlapjackConfigurator.configure_flapjack(@dummy_config, @test_container.api_url, @logger, true)
      expect(ret_val).to eq(true)
      expect(@test_diner.diner.entities('ALL')).to eq([{id: 'ALL', name: 'ALL', links: {contacts: [], checks: []}}])
    end
  end
end
